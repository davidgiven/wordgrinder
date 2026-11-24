package com.cowlark.wordgrinder.utils;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;
import java.lang.reflect.Constructor;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.ParameterizedType;
import java.lang.reflect.Type;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.Set;

public class Injector
{
    private final HashMap<Class<?>, Object> objects = new HashMap<>();

    /**
     * Supplies an existing instance for constructor injection.
     */
    public <T> void bindInstance(Class<T> type, T instance)
    {
        objects.put(type, instance);
    }

    /** Annotates a constructor as being eligible for injection. */
    @Retention(RetentionPolicy.RUNTIME)
    @Target(ElementType.CONSTRUCTOR)
    public @interface Inject
    {
    }

    /** Looks up a dependency on demand using this injector's instance cache. */
    @FunctionalInterface
    public interface Provider<T>
    {
        T get();
    }

    /**
     * Creates an instance using a public {@link Inject @Inject} constructor or a public
     * no-argument constructor. Constructor parameters are resolved recursively, except for
     * {@code Provider<T>} parameters, which look up their dependencies when called.
     *
     * @throws IllegalStateException if constructor dependencies form a cycle
     */
    public <T> T create(Class<T> theClass)
    {
        /* Track only the constructors on this resolution path. */
        return create(theClass, new LinkedHashSet<>());
    }

    @SuppressWarnings("unchecked")
    private <T> T create(Class<T> theClass, Set<Class<?>> resolving)
    {
        /* Reuse completed instances, including dependencies shared by multiple branches. */
        T obj = (T) objects.get(theClass);
        if (obj != null)
            return obj;

        /* Reject a constructor that needs an instance already under construction. */
        if (!resolving.add(theClass))
        {
            StringBuilder message = new StringBuilder("Recursive constructor dependency: ");
            for (Class<?> dependency : resolving)
                message.append(dependency.getName()).append(" -> ");
            throw new IllegalStateException(message.append(theClass.getName()).toString());
        }

        /* Resolve the constructor arguments before creating and caching the instance. */
        try
        {
            Constructor<T> constructor = findInjectableConstructor(theClass);
            Class<?>[] parameterTypes = constructor.getParameterTypes();
            Object[] parameters = new Object[parameterTypes.length];
            for (int i = 0; i < parameterTypes.length; i++)
            {
                parameters[i] = parameterTypes[i] == Provider.class
                        ? providerFor(constructor.getGenericParameterTypes()[i], resolving)
                        : create(parameterTypes[i], resolving);
            }

            /* Cache only successfully created instances. */
            obj = constructor.newInstance(parameters);
            objects.put(theClass, obj);
            return obj;
        }
        catch (NoSuchMethodException | InvocationTargetException | InstantiationException |
               IllegalAccessException e)
        {
            throw new RuntimeException(
                    String.format("Couldn't inject %s", theClass.getCanonicalName()),
                    e);
        }
        finally
        {
            resolving.remove(theClass);
        }
    }

    /* Resolve the provider's type now and defer creating the instance until get(). */
    private Provider<?> providerFor(Type parameter, Set<Class<?>> resolving)
    {
        if (parameter instanceof ParameterizedType provider
                && provider.getActualTypeArguments()[0] instanceof Class<?> dependency)
            return () -> create(dependency, resolving);

        throw new IllegalArgumentException("Provider requires a concrete dependency type: " + parameter);
    }

    @SuppressWarnings("unchecked")
    private static <T> Constructor<T> findInjectableConstructor(Class<T> theClass) throws NoSuchMethodException
    {
        /* Prefer an explicitly annotated public constructor. */
        for (Constructor<?> constructor : theClass.getConstructors())
            if (constructor.isAnnotationPresent(Inject.class))
                return (Constructor<T>) constructor;

        /* Use the public no-argument constructor as a fallback. */
        return theClass.getConstructor();
    }
}
