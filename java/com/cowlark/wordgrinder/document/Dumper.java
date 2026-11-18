package com.cowlark.wordgrinder.document;

import org.jspecify.annotations.NonNull;
import org.jspecify.annotations.Nullable;
import java.io.PrintStream;
import java.lang.reflect.Array;
import java.lang.reflect.Field;
import java.lang.reflect.Modifier;
import java.util.IdentityHashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;

/**
 * Writes the headerless dotted-path metadata format from fileio.lua.
 * Only fields marked {@link Dumpable} are traversed on ordinary objects. Lists and arrays
 * use one-based indices; map keys are strings. Null values represent absent Lua keys.
 * Fields and map keys are written alphabetically, for repeatable output.
 *
 * <p>The caller owns the stream; this class does not flush or close it. Document-set
 * headers and the special paragraph-text sections are outside this generic metadata writer.
 */
public class Dumper
{
    public void dump(@NonNull Object object, @NonNull PrintStream writer)
    {
        save("", object, writer, new IdentityHashMap<>());
    }

    private void save(
            @NonNull String path,
            @Nullable Object value,
            @NonNull PrintStream writer,
            @NonNull IdentityHashMap<Object, Boolean> active)
    {
        switch (value)
        {
            case null ->
            {
                return;
            }
            case String text ->
            {
                writeValue(path, quote(text), writer);
                return;
            }
            case Character character ->
            {
                writeValue(path, quote(character.toString()), writer);
                return;
            }
            case Boolean bool ->
            {
                writeValue(path, bool.toString(), writer);
                return;
            }
            case Number number ->
            {
                if (!Double.isFinite(number.doubleValue()))
                    throw new IllegalArgumentException("Non-finite number at " + path);
                String text = number.toString();
                if ((number instanceof Float || number instanceof Double) && text.endsWith(".0"))
                    text = text.substring(0, text.length() - 2);
                writeValue(path, text, writer);
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
                        save(path + "." + (i + 1), list.get(i), writer, active);
                }
                case Object array when array.getClass().isArray() ->
                {
                    for (int i = 0; i < Array.getLength(array); i++)
                        save(path + "." + (i + 1), Array.get(array, i), writer, active);
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
                        save(path + "." + entry.getKey(), entry.getValue(), writer, active);
                }
                default ->
                {
                    for (Map.Entry<String, Field> entry : fields(value.getClass()).entrySet())
                    {
                        Field field = entry.getValue();
                        try
                        {
                            field.setAccessible(true);
                            save(path + "." + entry.getKey(), field.get(value), writer, active);
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

    private @NonNull Map<String, Field> fields(@NonNull Class<?> type)
    {
        Map<String, Field> fields = new TreeMap<>();
        for (Class<?> current = type; current != null; current = current.getSuperclass())
        {
            for (Field field : current.getDeclaredFields())
            {
                Dumpable annotation = field.getAnnotation(Dumpable.class);
                if (annotation == null || field.isSynthetic() ||
                        Modifier.isStatic(field.getModifiers()))
                    continue;
                String name = annotation.value().isEmpty() ? field.getName() : annotation.value();
                if (fields.put(name, field) != null)
                    throw new IllegalArgumentException(
                            "Duplicate dump field " + name + " in " + type.getName());
            }
        }
        return fields;
    }

    private void writeValue(
            @NonNull String path,
            @NonNull String value,
            @NonNull PrintStream writer)
    {
        writer.print(path);
        writer.print(": ");
        writer.print(value);
        writer.print('\n');
    }

    /**
     * Uses the same four escapes as wg.escape: quote, backslash, CR and LF.
     */
    private @NonNull String quote(@NonNull String text)
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
