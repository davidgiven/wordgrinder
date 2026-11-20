package com.cowlark.wordgrinder.nativeinterface;

import org.teavm.interop.Address;
import org.teavm.interop.Import;
import org.teavm.interop.Strings;
import org.teavm.interop.c.Include;

/**
 * Bindings to the native display backend. Coordinates are (x, y).
 * Requires TeaVM's C backend and the nativeinterface native library.
 */
@Include("display.h")
public final class Display
{
    public static final int DPY_ITALIC = 1;
    public static final int DPY_UNDERLINE = 2;
    public static final int DPY_REVERSE = 4;
    public static final int DPY_BOLD = 8;
    public static final int DPY_BRIGHT = 16;
    public static final int DPY_DIM = 32;
    public static final int KEYM_MOUSE = 0x7f << 24;
    public static final int KEY_MOUSEDOWN = 1 << 24;
    public static final int KEY_MOUSEUP = 2 << 24;
    public static final int KEY_SCROLLUP = 3 << 24;
    public static final int KEY_SCROLLDOWN = 4 << 24;
    public static final int KEY_MENU = 5 << 24;
    public static final int KEY_RESIZE = 6 << 24;
    public static final int KEY_TIMEOUT = 7 << 24;
    public static final int KEY_QUIT = 8 << 24;

    private Display()
    {
    }

    /**
     * Pass command-line options to the backend before dpy_start().
     */
    public static void dpy_init(String[] args)
    {
        Address argv = malloc((args.length + 1L) * Address.sizeOf());
        if (argv == null)
            throw new OutOfMemoryError();
        int count = 0;
        try
        {
            for (String arg : args)
            {
                if (arg == null)
                    throw new NullPointerException("display argument");
                Address text = Strings.toC(arg);
                argv
                        .add(count * Address.sizeOf()).putAddress(text);
                count++;
            }
            argv
                    .add(count * Address.sizeOf()).putAddress(null);
            initNative(argv);
        } finally
        {
            for (int i = 0; i < count; i++)
                free(argv
                        .add(i * Address.sizeOf()).getAddress());
            free(argv);
        }
    }

    @Import(name = "wg_dpy_init")
    private static native void initNative(Address argv);

    /**
     * RGB components use the native colour_t range, 0.0 to 1.0.
     */
    @Import(name = "wg_dpy_setcolour")
    public static native void dpy_setcolour(
            float foregroundRed,
            float foregroundGreen,
            float foregroundBlue,
            float backgroundRed,
            float backgroundGreen,
            float backgroundBlue);

    /**
     * Returns {width, height}.
     */
    public static int[] dpy_getscreensize()
    {
        int[] size = new int[2];
        getScreenSizeNative(Address.ofData(size));
        Address.pin(size);
        return size;
    }

    @Import(name = "wg_dpy_getscreensize")
    private static native void getScreenSizeNative(Address size);

    public static String dpy_getkeyname(int key)
    {
        Address text = getKeyNameNative(key);
        if (text == null)
            throw new OutOfMemoryError();
        try
        {
            return Strings.fromC(text);
        } finally
        {
            free(text);
        }
    }

    @Import(name = "wg_dpy_getkeyname")
    private static native Address getKeyNameNative(int key);

    @Include(value = "stdlib.h", isSystem = true)
    @Import(name = "malloc")
    private static native Address malloc(long size);

    @Include(value = "stdlib.h", isSystem = true)
    @Import(name = "free")
    private static native void free(Address pointer);

    @Import(name = "wg_dpy_start")
    public static native void dpy_start();

    @Import(name = "wg_dpy_shutdown")
    public static native void dpy_shutdown();

    @Import(name = "wg_dpy_setattr")
    public static native void dpy_setattr(int andmask, int ormask);

    @Import(name = "wg_dpy_writechar")
    public static native void dpy_writechar(int x, int y, int c);

    @Import(name = "wg_dpy_setcursor")
    public static native void dpy_setcursor(int x, int y, boolean shown);

    @Import(name = "wg_dpy_clearscreen")
    public static native void dpy_clearscreen();

    @Import(name = "wg_dpy_sync")
    public static native void dpy_sync();

    @Import(name = "wg_dpy_cleararea")
    public static native void dpy_cleararea(int x1, int y1, int x2, int y2);

    /**
     * Terminal cell width of one Unicode code point, using the native locale.
     */
    @Import(name = "wg_screen_width")
    public static native int getCharacterWidth(int codePoint);

    @Import(name = "wg_dpy_getchar")
    public static native int dpy_getchar(double timeout);

}
