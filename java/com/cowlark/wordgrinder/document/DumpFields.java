package com.cowlark.wordgrinder.document;

import org.jspecify.annotations.NonNull;
import org.jspecify.annotations.Nullable;
import java.lang.reflect.Field;
import java.lang.reflect.Modifier;
import java.lang.reflect.ParameterizedType;
import java.util.Map;
import java.util.TreeMap;

/**
 * Shared validation of serialization field annotations.
 */
final class DumpFields
{
    static @NonNull Map<String, Field> fields(@NonNull Class<?> type)
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

    static @Nullable Field remaining(@NonNull Class<?> type)
    {
        Field result = null;
        for (Class<?> current = type; current != null; current = current.getSuperclass())
        {
            for (Field field : current.getDeclaredFields())
            {
                if (field.getAnnotation(RemainingDumpables.class) == null)
                    continue;
                if (Modifier.isStatic(field.getModifiers()) ||
                        !Map.class.isAssignableFrom(field.getType()) ||
                        field.getAnnotation(Dumpable.class) != null || result != null)
                    throw new IllegalArgumentException(
                            "Invalid @RemainingDumpables field " + field);
                if (!(field.getGenericType() instanceof ParameterizedType typeArguments) ||
                        typeArguments.getActualTypeArguments().length != 2 ||
                        typeArguments.getActualTypeArguments()[0] != String.class ||
                        typeArguments.getActualTypeArguments()[1] != String.class)
                    throw new IllegalArgumentException(
                            "@RemainingDumpables requires Map<String, String>: " + field);
                field.setAccessible(true);
                result = field;
            }
        }
        return result;
    }
}
