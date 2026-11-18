package com.cowlark.wordgrinder;

import org.teavm.interop.Function;
import org.teavm.interop.Import;
import org.teavm.interop.c.Include;

/**
 * Java equivalents of the screen operations exposed to Lua by src/c/screen.cc.
 */
@Include("display.h")
public final class Screen
{
    private static boolean running;
    private static boolean exitHandlerRegistered;
    private static int cursorx;
    private static int cursory;
    private static boolean cursorshown = true;
    private static boolean unicode = true;
    private static boolean oldMouseButton;

    private Screen()
    {
    }

    public static void screenInit(String[] args)
    {
        Display.dpy_init(args);
        unicode = defaultUnicode();
    }

    public static void initScreen()
    {
        Display.dpy_start();
        running = true;
        if (!exitHandlerRegistered)
        {
            registerExitHandler(Function.get(ExitHandler.class, Screen.class, "screenDeinit"));
            exitHandlerRegistered = true;
        }
    }

    public static void screenDeinit()
    {
        if (running)
        {
            Display.dpy_shutdown();
            running = false;
        }
    }

    public static void deinitScreen()
    {
        screenDeinit();
    }

    public static void clearScreen()
    {
        Display.dpy_clearscreen();
    }

    public static void sync()
    {
        Display.dpy_setcursor(cursorx, cursory, cursorshown);
        Display.dpy_sync();
    }

    public static void setBold()
    {
        Display.dpy_setattr(-1, Display.DPY_BOLD);
    }

    public static void setUnderline()
    {
        Display.dpy_setattr(-1, Display.DPY_UNDERLINE);
    }

    public static void setReverse()
    {
        Display.dpy_setattr(-1, Display.DPY_REVERSE);
    }

    public static void setBright()
    {
        Display.dpy_setattr(-1, Display.DPY_BRIGHT);
    }

    public static void setDim()
    {
        Display.dpy_setattr(-1, Display.DPY_DIM);
    }

    public static void setItalic()
    {
        Display.dpy_setattr(-1, Display.DPY_ITALIC);
    }

    public static void setNormal()
    {
        Display.dpy_setattr(0, 0);
    }

    /**
     * Each colour contains red, green, and blue components in the range 0 to 1.
     */
    public static void setColour(float[] foreground, float[] background)
    {
        Display.dpy_setcolour(
                foreground[0],
                foreground[1],
                foreground[2],
                background[0],
                background[1],
                background[2]);
    }

    public static void dpyWriteUniChar(int x, int y, int character)
    {
        Display.dpy_writechar(x, y, !unicode && character > 0xff ? '?' : character);
    }

    public static void write(int x, int y, String text)
    {
        for (int i = 0; i < text.length(); )
        {
            int character = text.codePointAt(i);
            i += Character.charCount(character);
            dpyWriteUniChar(x, y, character);
            if (!isControl(character))
                x += characterWidth(character);
        }
    }

    public static void clearArea(int x1, int y1, int x2, int y2)
    {
        Display.dpy_cleararea(x1, y1, x2, y2);
    }

    public static void gotoXY(int x, int y)
    {
        cursorx = x;
        cursory = y;
    }

    public static void showCursor()
    {
        cursorshown = true;
    }

    public static void hideCursor()
    {
        cursorshown = false;
    }

    /**
     * Returns {width, height}.
     */
    public static int[] getScreenSize()
    {
        return Display.dpy_getscreensize();
    }

    public static int getStringWidth(String text)
    {
        int width = 0;
        for (int i = 0; i < text.length(); )
        {
            int character = text.codePointAt(i);
            i += Character.charCount(character);
            if (!isControl(character))
                width += characterWidth(character);
        }
        return width;
    }

    public static String getBoundedString(String text, int width)
    {
        for (int i = 0; i < text.length(); )
        {
            int start = i;
            int character = text.codePointAt(i);
            i += Character.charCount(character);
            if (!isControl(character))
            {
                width -= characterWidth(character);
                if (width < 0)
                    return text.substring(0, start);
            }
        }
        return text;
    }

    /**
     * Length of a legacy UTF-8 sequence given its first byte, as in the Lua API.
     */
    public static int getBytesOfCharacter(int firstByte)
    {
        int c = firstByte & 0xff;
        if (c < 0x80)
            return 1;
        if (c < 0xc0)
            return 0;
        if (c < 0xe0)
            return 2;
        if (c < 0xf0)
            return 3;
        if (c < 0xf8)
            return 4;
        if (c < 0xfc)
            return 5;
        return 6;
    }

    public static MouseInputEvent decodeMouseEvent(int key)
    {
        boolean button = (key & Display.KEYM_MOUSE) == Display.KEY_MOUSEDOWN;
        return new MouseInputEvent(key & 0xff, (key >> 8) & 0xff, button, false);
    }

    public static InputEvent getEvent()
    {
        return getEvent(-1.0);
    }

    /**
     * Returns a KeyEvent for character text or symbolic key names, or a MouseEvent for button
     * events.
     */
    public static InputEvent getEvent(double timeout)
    {
        sync();
        for (; ; )
        {
            int character = Display.dpy_getchar(timeout);
            if (character <= 0)
            {
                int kind = -character & Display.KEYM_MOUSE;
                if (kind == Display.KEY_MOUSEDOWN || kind == Display.KEY_MOUSEUP)
                {
                    MouseInputEvent event = decodeMouseEvent(-character);
                    boolean clicked = event.b() && !oldMouseButton;
                    oldMouseButton = event.b();
                    return new MouseInputEvent(event.x(), event.y(), event.b(), clicked);
                }
                return new KeyInputEvent(Display.dpy_getkeyname(character));
            }
            if (characterWidth(character) > 0)
                return new KeyInputEvent(new String(Character.toChars(character)));
        }
    }

    public static boolean useUnicode()
    {
        return unicode;
    }

    public static void setUnicode(boolean enabled)
    {
        unicode = enabled;
    }

    @Import(name = "wg_screen_atexit")
    private static native void registerExitHandler(ExitHandler callback);

    @Import(name = "wg_screen_width")
    private static native int characterWidth(int character);

    @Import(name = "wg_screen_control")
    private static native boolean isControl(int character);

    @Import(name = "wg_screen_default_unicode")
    private static native boolean defaultUnicode();

    public sealed interface InputEvent permits MouseInputEvent, KeyInputEvent
    {
    }

    /**
     * Character text or a symbolic key name returned by the display backend.
     */
    public record KeyInputEvent(String key) implements InputEvent
    {
    }

    /**
     * Mouse coordinates, current button state, and whether this event is a new press.
     */
    public record MouseInputEvent(int x, int y, boolean b, boolean clicked) implements InputEvent
    {
    }

    public abstract static class ExitHandler extends Function
    {
        public abstract void invoke();
    }
}
