package com.cowlark.wordgrinder.teavm.impl;

import com.cowlark.wordgrinder.nativeinterface.Display;
import org.jspecify.annotations.NonNull;

import org.teavm.interop.Address;
import org.teavm.interop.Import;
import org.teavm.interop.c.Include;

/**
 * Bindings to the native display backend. Coordinates are (x, y).
 * Requires TeaVM's C backend and the teavm.impl native library.
 */
@Include("display.h")
public final class DisplayImpl implements Display
{

    @Import(name = "wg_dpy_init")
    private static native void initNative(Address argv);

    @Import(name = "wg_dpy_setcolour")
    private static native void dpy_setcolourNative(
            float foregroundRed,
            float foregroundGreen,
            float foregroundBlue,
            float backgroundRed,
            float backgroundGreen,
            float backgroundBlue);

    @Import(name = "wg_dpy_getscreensize")
    private static native void getScreenSizeNative(Address size);

    @Import(name = "wg_dpy_getkeyname")
    private static native Address getKeyNameNative(int key);

    @Include(value = "stdlib.h", isSystem = true)
    @Import(name = "malloc")
    private static native Address malloc(long size);

    @Include(value = "stdlib.h", isSystem = true)
    @Import(name = "free")
    private static native void free(Address pointer);

    @Import(name = "wg_dpy_start")
    private static native void dpy_startNative();

    @Import(name = "wg_dpy_shutdown")
    private static native void dpy_shutdownNative();

    @Import(name = "wg_dpy_setattr")
    private static native void dpy_setattrNative(int andmask, int ormask);

    @Import(name = "wg_dpy_writechar")
    private static native void dpy_writecharNative(int x, int y, int c);

    @Import(name = "wg_dpy_setcursor")
    private static native void dpy_setcursorNative(int x, int y, boolean shown);

    @Import(name = "wg_dpy_clearscreen")
    private static native void dpy_clearscreenNative();

    @Import(name = "wg_dpy_sync")
    private static native void dpy_syncNative();

    @Import(name = "wg_dpy_cleararea")
    private static native void dpy_clearareaNative(int x1, int y1, int x2, int y2);

    @Import(name = "wg_screen_width")
    private static native int getCharacterWidthNative(int codePoint);

    @Import(name = "wg_dpy_getchar")
    private static native int dpy_getcharNative(double timeout);

    /**
     * Pass command-line options to the backend before dpy_start().
     */
    @Override
    public void dpy_init(@NonNull String @NonNull [] args)
    {
        /* Retain every CString until the backend has consumed the complete argument vector. */
        CString[] strings = new CString[args.length];
        Address argv = malloc((args.length + 1L) * Address.sizeOf());
        if (argv == null)
            throw new OutOfMemoryError();
        try
        {
            for (int i = 0; i < args.length; i++)
            {
                strings[i] = new CString(args[i]);
                argv
                        .add(i * Address.sizeOf()).putAddress(strings[i].getAddress());
            }
            argv
                    .add(args.length * Address.sizeOf()).putAddress(null);
            initNative(argv);
        } finally
        {
            for (CString string : strings)
                if (string != null)
                    string.close();
            free(argv);
        }
    }

    /**
     * RGB components use the native colour_t range, 0.0 to 1.0.
     */
    @Override
    public void dpy_setcolour(
            float foregroundRed,
            float foregroundGreen,
            float foregroundBlue,
            float backgroundRed,
            float backgroundGreen,
            float backgroundBlue)
    {
        dpy_setcolourNative(
                foregroundRed,
                foregroundGreen,
                foregroundBlue,
                backgroundRed,
                backgroundGreen,
                backgroundBlue);
    }

    /**
     * Returns {width, height}.
     */
    @Override
    public int @NonNull [] dpy_getscreensize()
    {
        int[] size = new int[2];
        getScreenSizeNative(Address.ofData(size));
        Address.pin(size);
        return size;
    }

    @Override
    public @NonNull String dpy_getkeyname(int key)
    {
        Address text = getKeyNameNative(key);
        if (text == null)
            throw new OutOfMemoryError();
        try
        {
            return CString.fromC(text);
        } finally
        {
            free(text);
        }
    }

    @Override
    public void dpy_start()
    {
        dpy_startNative();
    }

    @Override
    public void dpy_shutdown()
    {
        dpy_shutdownNative();
    }

    @Override
    public void dpy_setattr(int andmask, int ormask)
    {
        dpy_setattrNative(andmask, ormask);
    }

    @Override
    public void dpy_writechar(int x, int y, int c)
    {
        dpy_writecharNative(x, y, c);
    }

    @Override
    public void dpy_setcursor(int x, int y, boolean shown)
    {
        dpy_setcursorNative(x, y, shown);
    }

    @Override
    public void dpy_clearscreen()
    {
        dpy_clearscreenNative();
    }

    @Override
    public void dpy_sync()
    {
        dpy_syncNative();
    }

    @Override
    public void dpy_cleararea(int x1, int y1, int x2, int y2)
    {
        dpy_clearareaNative(x1, y1, x2, y2);
    }

    /**
     * Terminal cell width of one Unicode code point, using the native locale.
     */
    @Override
    public int getCharacterWidth(int codePoint)
    {
        return getCharacterWidthNative(codePoint);
    }

    @Override
    public int dpy_getchar(double timeout)
    {
        return dpy_getcharNative(timeout);
    }

}
