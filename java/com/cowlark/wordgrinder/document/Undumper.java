package com.cowlark.wordgrinder.document;

import java.io.BufferedReader;
import java.io.IOException;
import java.lang.reflect.Array;
import java.lang.reflect.Field;
import java.lang.reflect.Modifier;
import java.lang.reflect.ParameterizedType;
import java.lang.reflect.Type;
import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;
import org.jspecify.annotations.NonNull;
import org.jspecify.annotations.Nullable;

/**
 * Reads Dumper's headerless text metadata into a mutable object. The caller owns
 * the reader. Missing properties retain their current values. Nested objects
 * may be preinitialised or have a no-argument constructor; final scalar fields
 * (including record components) cannot be assigned. Lists and maps must be mutable.
 * Unknown properties are kept by the nearest enclosing {@link RemainingDumpables} field;
 * an unknown property without such a field is an error rather than silent data loss.
 * Remaining-entry maps are cleared before reading the new unknown properties.
 * Invalid input can leave the target partially updated.
 */
public class Undumper
{
    public void undump(@NonNull Object object, @NonNull BufferedReader input) throws IOException
    {
        /* Parse the complete input before making changes to the object. */
        Node root = readInput(input);

        /* Populate the caller's object; replacing the root would lose the result. */
        Object result = read(root, object.getClass(), object, "", null);
        if (result != object)
            throw new IllegalArgumentException("The root object cannot be replaced");
    }

    private @NonNull Node readInput(@NonNull BufferedReader input) throws IOException
    {
        /* Read text without closing or replacing the caller's buffered reader. */
        Node root = new Node();
        String line;
        int lineNumber = 0;
        while ((line = input.readLine()) != null)
        {
            /* Separate each property path from its serialised value. */
            lineNumber++;
            int separator = line.indexOf(": ");
            if (separator < 0)
                throw new IllegalArgumentException("Malformed dump line " + lineNumber);
            String path = line.substring(0, separator);
            String raw = line.substring(separator + 2);
            if (!path.startsWith("."))
                throw new IllegalArgumentException("Invalid dump path " + path);
            parse(raw);

            /* Build the nested property tree, rejecting scalar/container conflicts. */
            Node node = root;
            for (String part : path.substring(1).split("\\.", -1))
            {
                if (part.isEmpty() || part.indexOf(':') >= 0 || node.raw != null)
                    throw new IllegalArgumentException("Conflicting dump path " + path);
                node = node.children.computeIfAbsent(part, key -> new Node());
            }
            if (node.raw != null || !node.children.isEmpty())
                throw new IllegalArgumentException("Duplicate or conflicting dump path " + path);
            node.raw = raw;
        }

        /* Keep raw values in the tree so unknown properties retain their spelling. */
        return root;
    }

    private @Nullable Object read(@NonNull Node node, @NonNull Type type, @Nullable Object current,
            @NonNull String path, @Nullable Remaining remaining)
    {
        /* Leaf nodes are scalar values, converted to the declared Java type. */
        Class<?> cls = rawType(type);
        if (node.raw != null)
            return convert(node.raw, cls, path);

        /* Untyped containers use their existing type, or a map when starting empty. */
        if (cls == Object.class)
            cls = current == null ? Map.class : current.getClass();

        /* Dispatch each container shape to its own reader. */
        if (Map.class.isAssignableFrom(cls))
            return readMap(node, type, current, path, remaining);
        if (List.class.isAssignableFrom(cls))
            return readList(node, type, current, path, remaining);
        if (cls.isArray())
            return readArray(node, cls.getComponentType(), current, path, remaining);
        return readObject(node, cls, current, path, remaining);
    }

    @SuppressWarnings("unchecked")
    private @NonNull Object readMap(@NonNull Node node, @NonNull Type type, @Nullable Object current,
            @NonNull String path, @Nullable Remaining remaining)
    {
        /* Merge entries using the map's declared value type. */
        Map<String, Object> map = current == null ? new LinkedHashMap<>() : (Map<String, Object>) current;
        Type valueType = argument(type, 1);
        for (Map.Entry<String, Node> entry : node.children.entrySet())
        {
            String key = entry.getKey();
            map.put(key, read(entry.getValue(), valueType, map.get(key), path + "." + key, remaining));
        }
        return map;
    }

    @SuppressWarnings("unchecked")
    private @NonNull Object readList(@NonNull Node node, @NonNull Type type, @Nullable Object current,
            @NonNull String path, @Nullable Remaining remaining)
    {
        /* Grow the list to accommodate the dump's one-based indices. */
        List<Object> list = current == null ? new ArrayList<>() : (List<Object>) current;
        Type elementType = argument(type, 0);
        for (Map.Entry<String, Node> entry : node.children.entrySet())
        {
            int index = index(entry.getKey());
            while (list.size() <= index)
                list.add(null);
            list.set(index, read(entry.getValue(), elementType, list.get(index),
                    path + "." + entry.getKey(), remaining));
        }
        return list;
    }

    private @NonNull Object readArray(@NonNull Node node, @NonNull Class<?> elementType,
            @Nullable Object current, @NonNull String path, @Nullable Remaining remaining)
    {
        /* Allocate enough room while retaining any existing elements. */
        int length = current == null ? 0 : Array.getLength(current);
        for (String key : node.children.keySet())
            length = Math.max(length, index(key) + 1);
        Object array = current;
        if (array == null || Array.getLength(array) != length)
        {
            array = Array.newInstance(elementType, length);
            if (current != null)
                System.arraycopy(current, 0, array, 0, Array.getLength(current));
        }

        /* Read elements using the array's component type, including primitive types. */
        for (Map.Entry<String, Node> entry : node.children.entrySet())
        {
            int index = index(entry.getKey());
            Array.set(array, index, read(entry.getValue(), elementType, Array.get(array, index),
                    path + "." + entry.getKey(), remaining));
        }
        return array;
    }

    private @NonNull Object readObject(@NonNull Node node, @NonNull Class<?> cls,
            @Nullable Object current, @NonNull String path, @Nullable Remaining remaining)
    {
        try
        {
            /* Reuse initialised objects, or construct a missing nested object. */
            Object target = current;
            if (target == null)
            {
                var constructor = cls.getDeclaredConstructor();
                constructor.setAccessible(true);
                target = constructor.newInstance();
            }

            /* This object's catch-all field takes precedence over its parent's. */
            remaining = remainingFor(target, path, remaining);
            Map<String, Field> fields = DumpFields.fields(cls);
            for (Map.Entry<String, Node> entry : node.children.entrySet())
            {
                /* Unknown subtrees go straight to the nearest catch-all map. */
                String childPath = path + "." + entry.getKey();
                Field field = fields.get(entry.getKey());
                if (field == null)
                {
                    preserve(entry.getValue(), childPath, remaining);
                    continue;
                }

                /* Populate known fields, allowing final containers to change in place. */
                field.setAccessible(true);
                Object old = field.get(target);
                boolean isFinal = Modifier.isFinal(field.getModifiers());
                if (entry.getValue().raw != null && isFinal)
                    throw new IllegalArgumentException("Cannot assign final dump field " + childPath);
                Object value = read(entry.getValue(), field.getGenericType(), old, childPath, remaining);
                if (value != old)
                {
                    if (isFinal)
                        throw new IllegalArgumentException("Cannot replace final dump field " + childPath);
                    field.set(target, value);
                }
            }
            return target;
        }
        catch (ReflectiveOperationException e)
        {
            /* Add the dump path to reflection failures for easier diagnosis. */
            throw new IllegalArgumentException("Cannot populate dump object at " + path, e);
        }
    }

    @SuppressWarnings("unchecked")
    private @Nullable Remaining remainingFor(@NonNull Object target, @NonNull String path,
            @Nullable Remaining parent) throws IllegalAccessException
    {
        /* Inherit the enclosing catch-all unless this object declares its own. */
        Field field = DumpFields.remaining(target.getClass());
        if (field == null)
            return parent;

        /* Prepare this object's map for the unknown entries in this input. */
        Map<String, String> values = (Map<String, String>) field.get(target);
        if (values == null)
        {
            values = new LinkedHashMap<>();
            field.set(target, values);
        }
        values.clear();
        return new Remaining(path, values);
    }

    private void preserve(@NonNull Node node, @NonNull String path, @Nullable Remaining remaining)
    {
        /* Store unknown leaves relative to their owner's path, without parsing again. */
        if (node.raw != null)
        {
            if (remaining == null)
                throw new IllegalArgumentException("Unmapped dump path " + path);
            remaining.values().put(path.substring(remaining.path().length()), node.raw);
            return;
        }

        /* Flatten every leaf of an unknown nested property into the same map. */
        for (Map.Entry<String, Node> entry : node.children.entrySet())
            preserve(entry.getValue(), path + "." + entry.getKey(), remaining);
    }

    private @NonNull Class<?> rawType(@NonNull Type type)
    {
        /* Collection fields retain their generic arguments separately from their class. */
        return switch (type)
        {
            case ParameterizedType parameterized -> (Class<?>) parameterized.getRawType();
            case Class<?> cls -> cls;
            default -> Object.class;
        };
    }

    private @NonNull Type argument(@NonNull Type type, int index)
    {
        /* Raw collections have no declared element type. */
        return type instanceof ParameterizedType parameterized
                ? parameterized.getActualTypeArguments()[index] : Object.class;
    }

    private int index(@NonNull String key)
    {
        /* Reject zero, negative indices, and noncanonical spellings such as 01. */
        int index = Integer.parseInt(key);
        if (index < 1 || !Integer.toString(index).equals(key))
            throw new IllegalArgumentException("Invalid one-based dump index " + key);
        return index - 1;
    }

    private @NonNull Object convert(@NonNull String raw, @NonNull Class<?> type, @NonNull String path)
    {
        /* Decode the value before checking whether the destination can hold it. */
        Object value = parse(raw);
        try
        {
            /* Untyped values keep the parser's natural representation. */
            if (type == Object.class)
                return value;

            /* Strings may also represent a single UTF-16 character. */
            if (value instanceof String text)
            {
                if (type == String.class)
                    return text;
                if ((type == char.class || type == Character.class) && text.length() == 1)
                    return text.charAt(0);
            }

            /* Booleans are only assignable to boolean fields. */
            if (value instanceof Boolean && (type == boolean.class || type == Boolean.class))
                return value;

            /* Numeric conversions must fit exactly, except for floating-point rounding. */
            if (value instanceof BigDecimal number)
            {
                /* Integral fields require an exact, in-range value. */
                if (type == byte.class || type == Byte.class)
                    return number.byteValueExact();
                if (type == short.class || type == Short.class)
                    return number.shortValueExact();
                if (type == int.class || type == Integer.class)
                    return number.intValueExact();
                if (type == long.class || type == Long.class)
                    return number.longValueExact();

                /* Floating-point fields may round, but must remain finite. */
                if (type == float.class || type == Float.class)
                {
                    float result = Float.parseFloat(raw);
                    if (Float.isFinite(result))
                        return result;
                }
                if (type == double.class || type == Double.class)
                {
                    double result = Double.parseDouble(raw);
                    if (Double.isFinite(result))
                        return result;
                }

                /* Arbitrary-precision fields retain the exact numeric value. */
                if (type == BigDecimal.class || type == Number.class)
                    return number;
                if (type == java.math.BigInteger.class)
                    return number.toBigIntegerExact();
            }
        }
        catch (ArithmeticException e)
        {
            /* Preserve the property path when an exact numeric conversion fails. */
            throw new IllegalArgumentException("Number out of range at " + path, e);
        }

        /* Reject mismatched types rather than silently discarding a known property. */
        throw new IllegalArgumentException("Invalid value for " + type.getName() + " at " + path + ": " + raw);
    }

    static @NonNull Object parse(@NonNull String raw)
    {
        /* Recognise the two boolean literals. */
        if (raw.equals("true"))
            return true;
        if (raw.equals("false"))
            return false;

        /* Quoted strings use exactly the four escapes written by Dumper. */
        if (raw.length() >= 2 && raw.charAt(0) == '"' && raw.charAt(raw.length() - 1) == '"')
        {
            StringBuilder text = new StringBuilder();
            for (int i = 1; i < raw.length() - 1; i++)
            {
                /* Reject an unescaped quote within the string. */
                char c = raw.charAt(i);
                if (c == '"')
                    throw new IllegalArgumentException("Unescaped quote in " + raw);

                /* Decode escapes, leaving ordinary characters unchanged. */
                if (c == '\\')
                {
                    if (++i >= raw.length() - 1)
                        throw new IllegalArgumentException("Unterminated escape in " + raw);
                    c = switch (raw.charAt(i))
                    {
                        case 'n' -> '\n';
                        case 'r' -> '\r';
                        case '\\' -> '\\';
                        case '"' -> '"';
                        default -> throw new IllegalArgumentException("Invalid escape in " + raw);
                    };
                }
                text.append(c);
            }
            return text.toString();
        }

        /* Keep numbers exact until the destination field's type is known. */
        if (!raw.matches("-?[0-9]+(\\.[0-9]+)?([eE][+-]?[0-9]+)?"))
            throw new IllegalArgumentException("Invalid dump value " + raw);
        return new BigDecimal(raw);
    }

    /* The nearest object's catch-all map and the path to which its keys are relative. */
    private record Remaining(@NonNull String path, @NonNull Map<String, String> values) {}

    /* A property is either a raw scalar value or a collection of child properties. */
    private static final class Node
    {
        @Nullable String raw;
        final @NonNull Map<String, Node> children = new TreeMap<>();
    }
}
