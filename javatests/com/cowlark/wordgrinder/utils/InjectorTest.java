package com.cowlark.wordgrinder.utils;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotSame;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertSame;
import static org.junit.Assert.assertThrows;
import static org.junit.Assert.assertTrue;

import com.cowlark.wordgrinder.utils.Injector.Inject;
import com.cowlark.wordgrinder.utils.Injector.Provider;
import java.lang.reflect.InvocationTargetException;
import org.junit.After;
import org.junit.Before;
import org.junit.Test;

public class InjectorTest
{
    /* Keep the shared cache empty at the start and end of each test. */
    @Before
    @After
    public void resetInjector()
    {
        Injector.resetForTesting();
    }

    /* Defer the back reference until its target is available in the injector cache. */
    @Test
    public void providerBreaksConstructorCycle()
    {
        LazyFirst first = Injector.create(LazyFirst.class);
        LazySecond second = first.second.get();

        /* Both directions use the same instances as ordinary injection. */
        assertSame(first, second.first);
        assertSame(second, first.second.get());
        assertSame(second, Injector.create(LazySecond.class));
    }

    /* A provider called inside the constructor still participates in cycle detection. */
    @Test
    public void providerCalledTooEarlyReportsCycle()
    {
        RuntimeException failure =
                assertThrows(RuntimeException.class, () -> Injector.create(EagerProvider.class));
        assertTrue(failure.getCause() instanceof InvocationTargetException);
        assertTrue(failure.getCause().getCause() instanceof IllegalStateException);
    }

    /* Hold a lazy reference to a type that has a direct dependency on this one. */
    public static class LazyFirst
    {
        final Provider<LazySecond> second;

        @Inject
        public LazyFirst(Provider<LazySecond> second)
        {
            this.second = second;
        }
    }

    /* Require the original instance when this dependency is finally created. */
    public static class LazySecond
    {
        final LazyFirst first;

        @Inject
        public LazySecond(LazyFirst first)
        {
            this.first = first;
        }
    }

    /* Force the provider before the injector has cached its target. */
    public static class EagerProvider
    {
        @Inject
        public EagerProvider(Provider<EagerProvider> self)
        {
            self.get();
        }
    }

    /* Reject self-injection and cycles that pass through a second type. */
    @Test
    public void rejectsRecursiveConstructorDependencies()
    {
        String prefix = "Recursive constructor dependency: ";
        String self = SelfDependent.class.getName();
        String first = First.class.getName();
        String second = Second.class.getName();

        /* Include the repeated type at the end of each chain. */
        assertEquals(prefix + self + " -> " + self,
                assertThrows(IllegalStateException.class,
                        () -> Injector.create(SelfDependent.class)).getMessage());
        assertEquals(prefix + first + " -> " + second + " -> " + first,
                assertThrows(IllegalStateException.class,
                        () -> Injector.create(First.class)).getMessage());
    }

    /* Select the annotated constructor and resolve both direct and transitive dependencies. */
    @Test
    public void injectsConstructorParametersRecursively() throws NoSuchMethodException
    {
        Service service = Injector.create(Service.class);

        /* The dependency reached by both paths is shared. */
        assertSame(service.dependency, service.intermediate.dependency);
        assertSame(service.dependency, Injector.create(Dependency.class));
        assertSame(service.intermediate, Injector.create(Intermediate.class));
    }

    /* Repeated requests reuse an instance until the cache is reset. */
    @Test
    public void cachesInstancesUntilReset() throws NoSuchMethodException
    {
        Dependency dependency = Injector.create(Dependency.class);
        assertSame(dependency, Injector.create(Dependency.class));
        Injector.resetForTesting();
        assertNotSame(dependency, Injector.create(Dependency.class));
    }

    /* A public no-argument constructor can be used without an annotation. */
    @Test
    public void fallsBackToNoArgumentConstructor() throws NoSuchMethodException
    {
        assertNotNull(Injector.create(Unannotated.class));
    }

    /* An unannotated constructor with parameters is ineligible. */
    @Test
    public void rejectsUnannotatedConstructorWithParameters()
    {
        RuntimeException failure =
                assertThrows(RuntimeException.class, () -> Injector.create(RequiresAnnotation.class));
        assertTrue(failure.getCause() instanceof NoSuchMethodException);
    }

    /* Report constructor failures with their original cause. */
    @Test
    public void preservesConstructorFailure()
    {
        RuntimeException failure =
                assertThrows(RuntimeException.class, () -> Injector.create(Failing.class));
        assertTrue(failure.getCause() instanceof InvocationTargetException);
        assertSame(Failing.FAILURE, failure.getCause().getCause());
    }

    /* Supply a shared dependency with no constructor parameters. */
    public static class Dependency
    {
        @Inject
        public Dependency()
        {
        }
    }

    /* Add an indirect path to the shared dependency. */
    public static class Intermediate
    {
        final Dependency dependency;

        @Inject
        public Intermediate(Dependency dependency)
        {
            this.dependency = dependency;
        }
    }

    /* Request two constructor arguments and provide an unannotated alternative. */
    public static class Service
    {
        final Dependency dependency;
        final Intermediate intermediate;

        public Service()
        {
            throw new AssertionError("Unannotated constructor was called");
        }

        @Inject
        public Service(Dependency dependency, Intermediate intermediate)
        {
            this.dependency = dependency;
            this.intermediate = intermediate;
        }
    }

    /* Provide a type with an implicit public no-argument constructor. */
    public static class Unannotated
    {
    }

    /* Request the same type directly. */
    public static class SelfDependent
    {
        @Inject
        public SelfDependent(SelfDependent dependency)
        {
        }
    }

    /* Request the same type indirectly through another constructor. */
    public static class First
    {
        @Inject
        public First(Second dependency)
        {
        }
    }

    public static class Second
    {
        @Inject
        public Second(First dependency)
        {
        }
    }

    /* Provide a type with neither an annotated nor a public no-argument constructor. */
    public static class RequiresAnnotation
    {
        public RequiresAnnotation(Dependency dependency)
        {
        }
    }

    /* Throw a recognisable exception from an injectable constructor. */
    public static class Failing
    {
        static final IllegalStateException FAILURE = new IllegalStateException("Constructor failed");

        @Inject
        public Failing()
        {
            throw FAILURE;
        }
    }
}
