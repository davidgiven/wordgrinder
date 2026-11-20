package com.cowlark.wordgrinder.teavm.impl;

import com.cowlark.wordgrinder.nativeinterface.System;
import org.teavm.interop.Import;
import org.teavm.interop.c.Include;

/**
 * Provides the C runtime's process termination operation.
 */
@Include(value = "stdlib.h", isSystem = true)
public final class SystemImpl implements System
{
    /* TeaVM maps this bridge directly to the C runtime. */
    @Import(name = "exit")
    private static native void exitNative(int status);

    /* Keep the native import behind the injected interface. */
    @Override
    public void exit(int status)
    {
        exitNative(status);
    }
}
