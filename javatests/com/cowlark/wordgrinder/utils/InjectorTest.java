package com.cowlark.wordgrinder.utils;

import static org.junit.Assert.assertNotSame;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertSame;
import static org.junit.Assert.assertThrows;
import static org.junit.Assert.assertTrue;

import com.cowlark.wordgrinder.utils.Injector.Inject;
import java.lang.reflect.InvocationTargetException;
import org.junit.Test;

public class InjectorTest
{
    /* Reject self-injection and cycles that pass through a second type. */
    @Test
    public void rejectsRecursiveConstructorDependencies()
    {
        Injector injector = new Injector();
        for (Class<?> type : new Class<?>[] {SelfDependent.class, First.class}) {
            IllegalStateException failure =
                    assertThrows(IllegalStateException.class, () -> injector.create(type));
            assertTrue(failure.getMessage().contains(type.getName()));
        }
    }

    /* Select the annotated constructor and resolve both direct and transitive dependencies. */
    @Test
    public void injectsConstructorParametersRecursively() throws NoSuchMethodException
    {
        Injector injector = new Injector();
        Service service = injector.create(Service.class);

        /* The dependency reached by both paths is shared. */
        assertSame(service.dependency, service.intermediate.dependency);
        assertSame(service.dependency, injector.create(Dependency.class));
        assertSame(service.intermediate, injector.create(Intermediate.class));
    }

    /* Repeated requests reuse an instance within one injector. */
    @Test
    public void cachesInstancesPerInjector() throws NoSuchMethodException
    {
        Injector injector = new Injector();
        Dependency dependency = injector.create(Dependency.class);
        assertSame(dependency, injector.create(Dependency.class));
        assertNotSame(dependency, new Injector().create(Dependency.class));
    }

    /* A public no-argument constructor can be used without an annotation. */
    @Test
    public void fallsBackToNoArgumentConstructor() throws NoSuchMethodException
    {
        assertNotNull(new Injector().create(Unannotated.class));
    }

    /* An unannotated constructor with parameters is ineligible. */
    @Test
    public void rejectsUnannotatedConstructorWithParameters()
    {
        Injector injector = new Injector();
        RuntimeException failure =
                assertThrows(RuntimeException.class, () -> injector.create(RequiresAnnotation.class));
        assertTrue(failure.getCause() instanceof NoSuchMethodException);
    }

    /* Report constructor failures with their original cause. */
    @Test
    public void preservesConstructorFailure()
    {
        Injector injector = new Injector();
        RuntimeException failure =
                assertThrows(RuntimeException.class, () -> injector.create(Failing.class));
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
