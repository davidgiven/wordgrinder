package com.cowlark.wordgrinder.teavm;

import org.teavm.extension.spi.reflection.SimpleReflectionPolicy;

/**
 * Enables serialization field access and nested-object construction in the compiled application.
 */
public final class DumpableReflectionPolicy extends SimpleReflectionPolicy
{
    @Override
    protected void setup()
    {
        var dumpable = withAnnotation("com.cowlark.wordgrinder.document.Dumpable");
        var remaining = withAnnotation("com.cowlark.wordgrinder.document.RemainingDumpables");
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
