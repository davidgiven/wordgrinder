package com.cowlark.wordgrinder.teavm.impl;

import org.jspecify.annotations.NonNull;
import org.jspecify.annotations.Nullable;
import org.teavm.interop.Address;
import org.teavm.interop.Import;
import org.teavm.interop.c.Include;

/**
 * Runs against the real TeaVM C runtime, including the native-call argument lifetimes.
 */
@Include("cstring-probe.h")
public final class CStringProbe
{
    /* Match the UTF-8 locale selected by the original native application. */
    @Import(name = "wg_cstring_test_init")
    private static native void initialiseLocale();

    /* Verify the C-visible bytes directly, without relying on a Java-side decoder. */
    @Import(name = "wg_cstring_test_check")
    private static native void checkNative(@NonNull Address address, int example);

    /* Validate the Java conversion against the platform's actual executable path rules. */
    @Import(name = "wg_cstring_test_executable_path")
    private static native void checkExecutablePathNative(@Nullable Address path);

    private static void checkString(@NonNull String text, int example)
    {
        try (CString cstring = new CString(text))
        {
            checkNative(cstring.getAddress(), example);
        }
    }

    /* Exercise the display and clipboard bridges using native assertions in the test stubs. */
    public static void main(String[] args)
    {
        initialiseLocale();
        int example = 0;
        for (String text : new String[]{"", "ASCII", "café 😀", "before\0after"})
            checkString(text, example++);
        DisplayImpl display = new DisplayImpl();
        display.dpy_init(new String[]{"--demo", "café 😀", ""});
        display.dpy_init(new String[0]);
        ClipboardImpl clipboard = new ClipboardImpl();
        clipboard.clipboardSet("before\0after 😀", new byte[]{0, 1, -1});
        clipboard.clipboardSet(null, null);
        clipboard.clipboardSet("", new byte[0]);

        /* Non-Windows must ignore WINDOWS_EXE even if a caller supplies it. */
        String executable = new SystemImpl().getExecutablePath();
        try (CString path = executable == null ? null : new CString(executable))
        {
            checkExecutablePathNative(path == null ? null : path.getAddress());
        }
    }
}
