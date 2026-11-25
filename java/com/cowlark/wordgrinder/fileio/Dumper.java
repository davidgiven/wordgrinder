package com.cowlark.wordgrinder.fileio;

import org.jspecify.annotations.Nullable;
import java.io.PrintWriter;
import java.lang.reflect.Array;
import java.lang.reflect.Field;
import java.util.IdentityHashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;

/**
 * Writes the headerless dotted-path metadata format from fileio.lua.
 * Only fields marked {@link Dumpable} are traversed on ordinary objects. Lists and arrays
 * use one-based indices; map keys are strings. Null values represent absent Lua keys.
 * Paths are written alphabetically, for repeatable output. Unknown entries stored
 * in {@link RemainingDumpables} fields are emitted with their original raw values.
 *
 * <p>The caller owns the writer; this class does not flush or close it. Document-set
 * headers and the special paragraph-text sections are outside this generic metadata writer.
 */
public class Dumper
{
    public void dump(Object object, PrintWriter writer)
    {
        Map<String, String> values = new TreeMap<>();
        save("", object, values, new IdentityHashMap<>());
        for (String path : values.keySet())
        {
            for (int dot = path.lastIndexOf('.'); dot > 0; dot = path.lastIndexOf('.', dot - 1))
            {
                if (values.containsKey(path.substring(0, dot)))
                    throw new IllegalArgumentException("Conflicting dump path " + path);
            }
        }
        for (Map.Entry<String, String> entry : values.entrySet())
        {
            writer.print(entry.getKey());
            writer.print(": ");
            writer.print(entry.getValue());
            writer.print('\n');
        }
    }

    private void save(
            String path,
            @Nullable Object value,
            Map<String, String> values,
            IdentityHashMap<Object, Boolean> active)
    {
        switch (value)
        {
            case null ->
            {
                return;
            }
            case String text ->
            {
                writeValue(path, quote(text), values);
                return;
            }
            case Character character ->
            {
                writeValue(path, quote(character.toString()), values);
                return;
            }
            case Boolean bool ->
            {
                writeValue(path, bool.toString(), values);
                return;
            }
            case Number number ->
            {
                /* The dump format supports signed integers up to 64 bits. */
                if (!(number instanceof Byte || number instanceof Short
                        || number instanceof Integer || number instanceof Long))
                    throw new IllegalArgumentException("Expected an integer at " + path);
                writeValue(path, Long.toString(number.longValue()), values);
                return;
            }
            default ->
            {
            }
        }

        if (active.put(value, true) != null)
            throw new IllegalArgumentException("Cyclic reference at " + path);
        try
        {
            switch (value)
            {
                case List<?> list ->
                {
                    for (int i = 0; i < list.size(); i++)
                        save(path + "." + (i + 1), list.get(i), values, active);
                }
                case Object array when array.getClass().isArray() ->
                {
                    for (int i = 0; i < Array.getLength(array); i++)
                        save(path + "." + (i + 1), Array.get(array, i), values, active);
                }
                case Map<?, ?> map ->
                {
                    Map<String, Object> sorted = new TreeMap<>();
                    for (Map.Entry<?, ?> entry : map.entrySet())
                    {
                        if (!(entry.getKey() instanceof String key))
                            throw new IllegalArgumentException("Non-string map key at " + path);
                        // Match Lua's omission of transient metadata keys.
                        if (!key.startsWith("_"))
                            sorted.put(key, entry.getValue());
                    }
                    for (Map.Entry<String, Object> entry : sorted.entrySet())
                        save(path + "." + entry.getKey(), entry.getValue(), values, active);
                }
                default ->
                {
                    Field remaining = DumpFields.remaining(value.getClass());
                    if (remaining != null)
                    {
                        try
                        {
                            Object extras = remaining.get(value);
                            if (extras instanceof Map<?, ?> entries)
                            {
                                for (Map.Entry<?, ?> entry : entries.entrySet())
                                {
                                    if (!(entry.getKey() instanceof String key) ||
                                            !key.startsWith(".") ||
                                            !(entry.getValue() instanceof String raw) ||
                                            key.endsWith(".") || key.contains("..") ||
                                            key.indexOf(':') >= 0 || key.indexOf('\n') >= 0 ||
                                            key.indexOf('\r') >= 0 || raw.indexOf('\n') >= 0 ||
                                            raw.indexOf('\r') >= 0)
                                        throw new IllegalArgumentException(
                                                "Invalid remaining dump entry " + entry);
                                    Undumper.parse(raw);
                                    writeValue(path + key, raw, values);
                                }
                            }
                        } catch (IllegalAccessException e)
                        {
                            throw new IllegalArgumentException(
                                    "Cannot read remaining dump fields" + " at " + path,
                                    e);
                        }
                    }
                    for (Map.Entry<String, Field> entry : DumpFields
                            .fields(value.getClass())
                            .entrySet())
                    {
                        Field field = entry.getValue();
                        try
                        {
                            field.setAccessible(true);
                            String fieldPath = path + "." + entry.getKey();

                            /* Omit an unset index and widen before converting set indices. */
                            if (field.getAnnotation(Dumpable.class).oneOffset())
                            {
                                int index = (int) field.get(value);
                                if (index != -1)
                                    writeValue(fieldPath, Long.toString((long) index + 1), values);
                            }
                            else
                                save(fieldPath, field.get(value), values, active);
                        } catch (IllegalAccessException e)
                        {
                            throw new IllegalArgumentException(
                                    "Cannot read field " + field.getName() + " at " + path,
                                    e);
                        }
                    }
                }
            }
        } finally
        {
            active.remove(value);
        }
    }

    private void writeValue(String path, String value, Map<String, String> values)
    {
        if (values.putIfAbsent(path, value) != null)
            throw new IllegalArgumentException("Duplicate dump path " + path);
    }

    /**
     * Uses the same four escapes as wg.escape: quote, backslash, CR and LF.
     */
    private String quote(String text)
    {
        StringBuilder escaped = new StringBuilder(text.length() + 2).append('"');
        for (int i = 0; i < text.length(); i++)
        {
            char c = text.charAt(i);
            switch (c)
            {
                case '\\' -> escaped.append("\\\\");
                case '"' -> escaped.append("\\\"");
                case '\n' -> escaped.append("\\n");
                case '\r' -> escaped.append("\\r");
                default -> escaped.append(c);
            }
        }
        return escaped.append('"').toString();
    }
}
