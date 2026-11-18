package com.cowlark.wordgrinder.teavm;

import org.teavm.extension.spi.reflection.SimpleReflectionPolicy;

/** Enables reflective reads of dumpable fields in the compiled application. */
public final class DumpableReflectionPolicy extends SimpleReflectionPolicy
{
    @Override
    protected void setup()
    {
        allClasses().reflectableFields(
            withAnnotation("com.cowlark.wordgrinder.document.Dumpable"));
    }
}
