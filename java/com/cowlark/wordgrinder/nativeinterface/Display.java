/* © 2026 David Given.
 * WordGrinder is licensed under the MIT open source licence. See COPYING.
 */

package com.cowlark.wordgrinder.nativeinterface;


/**
 * Backend-independent display operations.
 */
public interface Display
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

    /* Operations are supplied by an injected backend instance. */
    void dpy_init(String[] args);

    int[] dpy_getscreensize();

    String dpy_getkeyname(int key);

    /**
     * Colour components are in the range 0 to 1.
     */
    void dpy_setcolour(
            float foregroundRed,
            float foregroundGreen,
            float foregroundBlue,
            float backgroundRed,
            float backgroundGreen,
            float backgroundBlue);

    void dpy_start();

    void dpy_shutdown();

    void dpy_setattr(int andmask, int ormask);

    void dpy_writechar(int x, int y, int c);

    void dpy_setcursor(int x, int y, boolean shown);

    void dpy_clearscreen();

    void dpy_sync();

    void dpy_cleararea(int x1, int y1, int x2, int y2);

    int getCharacterWidth(int codePoint);

    int dpy_getchar(double timeout);
}
