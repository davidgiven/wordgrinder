package com.cowlark.wordgrinder.teavm;

import org.teavm.extension.spi.reflection.SimpleReflectionPolicy;

/**
 * Enables reflection for serialisation and constructor injection.
 */
public final class DumpableReflectionPolicy extends SimpleReflectionPolicy
{
    @Override
    protected void setup()
    {
        /* Preserve injectable constructors in the native build. */
        var injectable = withAnnotation("com.cowlark.wordgrinder.utils.Injector$Inject");
        allClasses().reflectableMethods(method -> injectable.test(method));

        /* Keep Navigation's implicit constructor available to the injector. */
        selectClass("com.cowlark.wordgrinder.app.Navigation")
                .reflectableMethods(withParameterCount(0).and(named("<init>")).and(PUBLIC));

        /* Preserve serialised fields and constructors for nested values. */
        var dumpable = withAnnotation("com.cowlark.wordgrinder.fileio.Dumpable");
        var remaining = withAnnotation("com.cowlark.wordgrinder.fileio.RemainingDumpables");
        allClasses().reflectableFields(dumpable.or(remaining));
        selectClasses(cls -> {
            for (var current = cls; current != null; current = current.superclass())
            {
                if (current.declaredFields().stream().anyMatch(dumpable.or(remaining)))
                    return true;
            }
            return false;
        }).reflectableMethods(withParameterCount(0).and(named("<init>")));
    }
}
