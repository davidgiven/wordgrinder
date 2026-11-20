package com.cowlark.wordgrinder.teavm.impl;

import com.cowlark.wordgrinder.nativeinterface.System;
import org.jspecify.annotations.Nullable;
import org.teavm.interop.Address;
import org.teavm.interop.Import;
import org.teavm.interop.c.Include;

/**
 * Supplies application paths and process control through the C runtime.
 */
@Include(value = "stdlib.h", isSystem = true)
public final class SystemImpl implements System
{
    /* TeaVM maps this bridge directly to the C runtime. */
    @Import(name = "exit")
    private static native void exitNative(int status);

    /* Environment values remain owned by the C runtime. */
    @Import(name = "getenv")
    private static native @Nullable Address getenvNative(Address name);

    /* The platform bridge discovers and exposes the Windows executable path. */
    @Include("system.h")
    @Import(name = "wg_system_get_executable_path")
    private static native @Nullable Address getExecutablePathNative();

    /* Copy the environment value before releasing only the temporary variable name. */
    private static @Nullable String getenv(String name)
    {
        try (CString cstring = new CString(name))
        {
            return CString.fromC(getenvNative(cstring.getAddress()));
        }
    }

    /* Match main.lua's HOME, USERPROFILE and relative-directory fallback order. */
    @Override
    public String getConfigDirectory()
    {
        String home = getenv("HOME");
        if (home == null)
            home = getenv("USERPROFILE");
        if (home == null)
            home = ".";
        return home + "/.wordgrinder";
    }

    /* Copy the path from the native bridge's persistent buffer. */
    @Override
    public @Nullable String getExecutablePath()
    {
        return CString.fromC(getExecutablePathNative());
    }

    /* Keep the native import behind the injected interface. */
    @Override
    public void exit(int status)
    {
        exitNative(status);
    }
}
