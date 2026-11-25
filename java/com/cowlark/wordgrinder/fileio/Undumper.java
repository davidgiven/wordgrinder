package com.cowlark.wordgrinder.fileio;

import org.jspecify.annotations.Nullable;
import java.io.BufferedReader;
import java.io.IOException;
import java.lang.reflect.Array;
import java.lang.reflect.Field;
import java.lang.reflect.Modifier;
import java.lang.reflect.ParameterizedType;
import java.lang.reflect.Type;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;

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
    static Object parse(String raw)
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

        /* Parse signed decimal integers without narrowing to the destination type yet. */
        if (!raw.matches("-?[0-9]+"))
            throw new IllegalArgumentException("Invalid dump value " + raw);
        return Long.parseLong(raw);
    }

    public void undump(Object object, BufferedReader input) throws IOException
    {
        /* Parse the complete input before making changes to the object. */
        Node root = readInput(input);

        /* Populate the caller's object; replacing the root would lose the result. */
        Object result = read(root, object.getClass(), object, "", null);
        if (result != object)
            throw new IllegalArgumentException("The root object cannot be replaced");
    }

    private Node readInput(BufferedReader input) throws IOException
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

    private @Nullable Object read(
            Node node,
            Type type,
            @Nullable Object current,
            String path,
            @Nullable Remaining remaining)
    {
        /* Leaf nodes are scalar values, converted to the declared Java type. */
        Class<?> cls = rawType(type);
        if (node.raw != null)
            return convert(node.raw, cls, path, false);

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
    private Object readMap(
            Node node,
            Type type,
            @Nullable Object current,
            String path,
            @Nullable Remaining remaining)
    {
        /* Merge entries using the map's declared value type. */
        Map<String, Object> map =
                current == null ? new LinkedHashMap<>() : (Map<String, Object>) current;
        Type valueType = argument(type, 1);
        for (Map.Entry<String, Node> entry : node.children.entrySet())
        {
            String key = entry.getKey();
            map.put(
                    key,
                    read(entry.getValue(), valueType, map.get(key), path + "." + key, remaining));
        }
        return map;
    }

    @SuppressWarnings("unchecked")
    private Object readList(
            Node node,
            Type type,
            @Nullable Object current,
            String path,
            @Nullable Remaining remaining)
    {
        /* Grow the list to accommodate the dump's one-based indices. */
        List<Object> list = current == null ? new ArrayList<>() : (List<Object>) current;
        Type elementType = argument(type, 0);
        for (Map.Entry<String, Node> entry : node.children.entrySet())
        {
            int index = index(entry.getKey());
            while (list.size() <= index)
                list.add(null);
            list.set(
                    index, read(
                            entry.getValue(),
                            elementType,
                            list.get(index),
                            path + "." + entry.getKey(),
                            remaining));
        }
        return list;
    }

    private Object readArray(
            Node node,
            Class<?> elementType,
            @Nullable Object current,
            String path,
            @Nullable Remaining remaining)
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
            Array.set(
                    array, index, read(
                            entry.getValue(),
                            elementType,
                            Array.get(array, index),
                            path + "." + entry.getKey(),
                            remaining));
        }
        return array;
    }

    private Object readObject(
            Node node,
            Class<?> cls,
            @Nullable Object current,
            String path,
            @Nullable Remaining remaining)
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
                    throw new IllegalArgumentException(
                            "Cannot assign final dump field " + childPath);
                /* Convert on the file side of the integral range check. */
                Node child = entry.getValue();
                Object value;
                if (field.getAnnotation(Dumpable.class).oneOffset())
                {
                    if (child.raw == null)
                        throw new IllegalArgumentException("Expected an integer value at " + childPath);
                    value = convert(child.raw, field.getType(), childPath, true);
                }
                else
                    value = read(child, field.getGenericType(), old, childPath, remaining);
                if (value != old)
                {
                    if (isFinal)
                        throw new IllegalArgumentException(
                                "Cannot replace final dump field " + childPath);
                    field.set(target, value);
                }
            }
            return target;
        } catch (ReflectiveOperationException e)
        {
            /* Add the dump path to reflection failures for easier diagnosis. */
            throw new IllegalArgumentException("Cannot populate dump object at " + path, e);
        }
    }

    @SuppressWarnings("unchecked")
    private @Nullable Remaining remainingFor(Object target, String path, @Nullable Remaining parent)
            throws IllegalAccessException
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

    private void preserve(Node node, String path, @Nullable Remaining remaining)
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

    private Class<?> rawType(Type type)
    {
        /* Collection fields retain their generic arguments separately from their class. */
        return switch (type)
        {
            case ParameterizedType parameterized -> (Class<?>) parameterized.getRawType();
            case Class<?> cls -> cls;
            default -> Object.class;
        };
    }

    private Type argument(Type type, int index)
    {
        /* Raw collections have no declared element type. */
        return type instanceof ParameterizedType parameterized ?
                parameterized.getActualTypeArguments()[index] :
                Object.class;
    }

    private int index(String key)
    {
        /* Reject zero, negative indices, and noncanonical spellings such as 01. */
        int index = Integer.parseInt(key);
        if (index < 1 || !Integer.toString(index).equals(key))
            throw new IllegalArgumentException("Invalid one-based dump index " + key);
        return index - 1;
    }

    private Object convert(String raw, Class<?> type, String path, boolean oneOffset)
    {
        /* Decode the value before checking whether the destination can hold it. */
        Object value = parse(raw);
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

        /* Convert the file offset before checking the destination range. */
        if (value instanceof Long parsed)
        {
            long number = parsed;
            if (oneOffset)
            {
                if (number == Long.MIN_VALUE)
                    throw new IllegalArgumentException("Number out of range at " + path);
                number--;
            }

            /* Narrow only when the integer fits the destination type exactly. */
            if (type == byte.class || type == Byte.class)
            {
                if (number >= Byte.MIN_VALUE && number <= Byte.MAX_VALUE)
                    return (byte) number;
                throw new IllegalArgumentException("Number out of range at " + path);
            }
            if (type == short.class || type == Short.class)
            {
                if (number >= Short.MIN_VALUE && number <= Short.MAX_VALUE)
                    return (short) number;
                throw new IllegalArgumentException("Number out of range at " + path);
            }
            if (type == int.class || type == Integer.class)
            {
                if (number >= Integer.MIN_VALUE && number <= Integer.MAX_VALUE)
                    return (int) number;
                throw new IllegalArgumentException("Number out of range at " + path);
            }
            if (type == long.class || type == Long.class || type == Number.class)
                return number;
        }

        /* Reject mismatched types rather than silently discarding a known property. */
        throw new IllegalArgumentException(
                "Invalid value for " + type.getName() + " at " + path + ": " + raw);
    }

    /* The nearest object's catch-all map and the path to which its keys are relative. */
    private record Remaining(String path, Map<String, String> values)
    {
    }

    /* A property is either a raw scalar value or a collection of child properties. */
    private static final class Node
    {
        final Map<String, Node> children = new TreeMap<>();
        @Nullable String raw;
    }
}
