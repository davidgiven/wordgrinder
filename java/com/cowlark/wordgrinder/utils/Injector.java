package com.cowlark.wordgrinder.utils;

import com.google.common.annotations.VisibleForTesting;
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

public final class Injector
{
    /* Share explicit bindings and constructed instances across the application. */
    private static final HashMap<Class<?>, Object> objects = new HashMap<>();

    private Injector()
    {
    }

    /**
     * Supplies an existing instance for constructor injection.
     */
    public static <T> void bindInstance(Class<T> type, T instance)
    {
        objects.put(type, instance);
    }

    /** Clears all bindings and cached instances before setting up a test. */
    @VisibleForTesting
    public static void resetForTesting()
    {
        objects.clear();
    }

    /** Removes a test binding so the next lookup can resolve the type normally. */
    @VisibleForTesting
    public static void removeBindingForTesting(Class<?> type)
    {
        objects.remove(type);
    }

    /** Annotates a constructor as being eligible for injection. */
    @Retention(RetentionPolicy.RUNTIME)
    @Target(ElementType.CONSTRUCTOR)
    public @interface Inject
    {
    }

    /** Looks up a dependency on demand using the shared instance cache. */
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
    public static <T> T create(Class<T> theClass)
    {
        /* Track only the constructors on this resolution path. */
        return create(theClass, new LinkedHashSet<>(), true);
    }

    /** Constructs a fresh instance while resolving its dependencies through the usual cache. */
    public static <T> T createFresh(Class<T> type)
    {
        return create(type, new LinkedHashSet<>(), false);
    }

    @SuppressWarnings("unchecked")
    private static <T> T create(Class<T> theClass, Set<Class<?>> resolving, boolean reuse)
    {
        /* Reuse completed instances, including dependencies shared by multiple branches. */
        if (reuse)
        {
            T cached = (T) objects.get(theClass);
            if (cached != null)
                return cached;
        }

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
                        : create(parameterTypes[i], resolving, true);
            }

            /* Cache successfully created instances only when reuse was requested. */
            T obj = constructor.newInstance(parameters);
            if (reuse)
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
    private static Provider<?> providerFor(Type parameter, Set<Class<?>> resolving)
    {
        if (parameter instanceof ParameterizedType provider
                && provider.getActualTypeArguments()[0] instanceof Class<?> dependency)
            return () -> create(dependency, resolving, true);

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
