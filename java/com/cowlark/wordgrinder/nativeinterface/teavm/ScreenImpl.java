package com.cowlark.wordgrinder.nativeinterface.teavm;

import com.cowlark.wordgrinder.nativeinterface.Colour;
import com.cowlark.wordgrinder.nativeinterface.Display;
import com.cowlark.wordgrinder.nativeinterface.Screen;
import org.teavm.interop.Import;
import org.teavm.interop.c.Include;

/**
 * Java equivalents of the screen operations exposed to Lua by src/c/screen.cc.
 */
@Include("display.h")
public final class ScreenImpl implements Screen
{
    /* Retain the supplied display and keep screen state local to this instance. */
    private final Display display;
    private boolean running;
    private int cursorx;
    private int cursory;
    private boolean cursorshown = true;
    private boolean unicode = true;
    private boolean oldMouseButton;

    public ScreenImpl(Display display)
    {
        this.display = display;
    }

    @Import(name = "wg_screen_width")
    private static native int characterWidth(int character);

    @Import(name = "wg_screen_control")
    private static native boolean isControl(int character);

    @Import(name = "wg_screen_default_unicode")
    private static native boolean defaultUnicode();

    @Override
    public void screenInit(String[] args)
    {
        display.dpy_init(args);
        unicode = defaultUnicode();
    }

    @Override
    public void initScreen()
    {
        display.dpy_start();
        running = true;
    }

    @Override
    public void screenDeinit()
    {
        if (running)
        {
            display.dpy_shutdown();
            running = false;
        }
    }

    @Override
    public void deinitScreen()
    {
        screenDeinit();
    }

    @Override
    public void clearScreen()
    {
        display.dpy_clearscreen();
    }

    @Override
    public void sync()
    {
        display.dpy_setcursor(cursorx, cursory, cursorshown);
        display.dpy_sync();
    }

    @Override
    public void setBold()
    {
        display.dpy_setattr(-1, Display.DPY_BOLD);
    }

    @Override
    public void setUnderline()
    {
        display.dpy_setattr(-1, Display.DPY_UNDERLINE);
    }

    @Override
    public void setReverse()
    {
        display.dpy_setattr(-1, Display.DPY_REVERSE);
    }

    @Override
    public void setBright()
    {
        display.dpy_setattr(-1, Display.DPY_BRIGHT);
    }

    @Override
    public void setDim()
    {
        display.dpy_setattr(-1, Display.DPY_DIM);
    }

    @Override
    public void setItalic()
    {
        display.dpy_setattr(-1, Display.DPY_ITALIC);
    }

    @Override
    public void setNormal()
    {
        display.dpy_setattr(0, 0);
    }

    /**
     * Each colour contains red, green, and blue components in the range 0 to 1.
     */
    @Override
    public void setColour(Colour foreground, Colour background)
    {
        display.dpy_setcolour(
                foreground.red(),
                foreground.green(),
                foreground.blue(),
                background.red(),
                background.green(),
                background.blue());
    }

    @Override
    public void dpyWriteUniChar(int x, int y, int character)
    {
        display.dpy_writechar(x, y, !unicode && character > 0xff ? '?' : character);
    }

    @Override
    public void write(int x, int y, String text)
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

    @Override
    public void clearArea(int x1, int y1, int x2, int y2)
    {
        display.dpy_cleararea(x1, y1, x2, y2);
    }

    @Override
    public void gotoXY(int x, int y)
    {
        cursorx = x;
        cursory = y;
    }

    @Override
    public void showCursor()
    {
        cursorshown = true;
    }

    @Override
    public void hideCursor()
    {
        cursorshown = false;
    }

    /**
     * Returns {width, height}.
     */
    @Override
    public int[] getScreenSize()
    {
        return display.dpy_getscreensize();
    }

    @Override
    public int getStringWidth(String text)
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

    @Override
    public String getBoundedString(String text, int width)
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
    @Override
    public int getBytesOfCharacter(int firstByte)
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

    @Override
    public MouseInputEvent decodeMouseEvent(int key)
    {
        boolean button = (key & Display.KEYM_MOUSE) == Display.KEY_MOUSEDOWN;
        return new MouseInputEvent(key & 0xff, (key >> 8) & 0xff, button, false);
    }

    @Override
    public InputEvent getEvent()
    {
        return getEvent(-1.0);
    }

    /**
     * Returns a KeyEvent for character text or symbolic key names, or a MouseEvent for button
     * events.
     */
    @Override
    public InputEvent getEvent(double timeout)
    {
        sync();
        for (; ; )
        {
            int character = display.dpy_getchar(timeout);
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
                return new KeyInputEvent(display.dpy_getkeyname(character));
            }
            if (characterWidth(character) > 0)
                return new KeyInputEvent(new String(Character.toChars(character)));
        }
    }

    @Override
    public boolean useUnicode()
    {
        return unicode;
    }

    @Override
    public void setUnicode(boolean enabled)
    {
        unicode = enabled;
    }

}
