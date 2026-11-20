/* © 2026 David Given.
 * WordGrinder is licensed under the MIT open source licence. See COPYING.
 */

package com.cowlark.wordgrinder.forms;

import com.cowlark.wordgrinder.nativeinterface.Screen;
import com.cowlark.wordgrinder.nativeinterface.Screen.InputEvent;
import com.cowlark.wordgrinder.nativeinterface.Screen.KeyInputEvent;
import org.jspecify.annotations.NonNull;
import org.jspecify.annotations.Nullable;

/** Screen helpers shared by forms, translated from ui.lua and redraw.lua. */
public final class Ui
{
    /* Match the cursor timings declared in the Lua prologue, in seconds. */
    public static final double BLINK_ON_TIME = 0.8;
    public static final double BLINK_OFF_TIME = 0.53;

    /* This class contains only stateless screen operations. */
    private Ui() {}

    /** Draws a reversed status line on the bottom screen row. */
    public static void drawStatusLine(@NonNull String text)
    {
        /* Query the current size rather than retaining document redraw state. */
        int[] size = Screen.getScreenSize();
        Screen.setReverse();
        Screen.clearArea(0, size[1] - 1, size[0] - 1, size[1] - 1);
        Screen.write(0, size[1] - 1, text);
        Screen.setNormal();
    }

    /**
     * Draws and clears a box with an interior of width by height cells.
     * The top-left corner is (x, y); the interior starts at (x + 1, y + 1).
     * As in Lua, a column outside each vertical border is also cleared.
     */
    public static void drawBox(int x, int y, int width, int height)
    {
        /* Draw the corners and horizontal borders in the selected character set. */
        boolean unicode = Screen.useUnicode();
        String border = (unicode ? "─" : "-").repeat(width);
        String space = " ".repeat(width);
        Screen.write(x - 1, y, unicode ? " ┌" : " +");
        Screen.write(x + width + 1, y, unicode ? "┐ " : "+ ");
        Screen.write(x - 1, y + height + 1, unicode ? " └" : " +");
        Screen.write(x + width + 1, y + height + 1, unicode ? "┘ " : "+ ");
        Screen.write(x + 1, y, border);
        Screen.write(x + 1, y + height + 1, border);

        /* Clear the interior and draw its vertical borders. */
        for (int row = y + 1; row <= y + height; row++)
        {
            Screen.write(x - 1, row, unicode ? " │" : " |");
            Screen.write(x + width + 1, row, unicode ? "│ " : "| ");
            Screen.write(x + 1, row, space);
        }
    }

    /** Clips text to the field's cell width and centres it without clearing the field. */
    public static void centreInField(int x, int y, int width, @NonNull String text)
    {
        /* Align using terminal cell widths rather than Java string lengths. */
        String bounded = Screen.getBoundedString(text, width);
        int offset = Math.floorDiv(width - Screen.getStringWidth(bounded), 2);
        Screen.write(x + offset, y, bounded);
    }

    /** Clips text and aligns it to the left without clearing the field. */
    public static void lAlignInField(int x, int y, int width, @NonNull String text)
    {
        /* Clipping preserves complete Unicode code points. */
        Screen.write(x, y, Screen.getBoundedString(text, width));
    }

    /** Clips text and aligns it to the right without clearing the field. */
    public static void rAlignInField(int x, int y, int width, @NonNull String text)
    {
        /* Measure the clipped text so it ends at the field's right edge. */
        String bounded = Screen.getBoundedString(text, width);
        Screen.write(x + width - Screen.getStringWidth(bounded), y, bounded);
    }

    /** Draws a bright box with a centred title on its top border. */
    public static void drawTitledBox(int x, int y, int width, int height, @NonNull String title)
    {
        /* A missing subtitle leaves the lower border uninterrupted. */
        drawTitledBox(x, y, width, height, title, null);
    }

    /** Draws a titled box with an optional bold subtitle on its bottom border. */
    public static void drawTitledBox(
            int x, int y, int width, int height, @NonNull String title, @Nullable String subtitle)
    {
        /* Restore normal attributes after drawing both border captions. */
        Screen.setBright();
        drawBox(x, y, width, height);
        centreInField(x + 1, y, width, title);
        if (subtitle != null)
        {
            Screen.setBold();
            centreInField(x + 1, y + height + 1, width, subtitle);
        }
        Screen.setNormal();
    }

    /** Displays a centred boxed message immediately, without waiting for input. */
    public static void immediateMessage(@NonNull String text)
    {
        /* Match the Lua message's padding and placement on the current screen. */
        int[] size = Screen.getScreenSize();
        int width = Screen.getStringWidth(text);
        int x = Math.floorDiv(size[0] - width, 2);
        int y = Math.floorDiv(size[1], 2);
        drawBox(x - 2, y - 1, width + 2, 1);
        Screen.write(x, y, text);
        Screen.sync();
    }

    /** Waits for an input event while blinking the cursor. */
    public static @NonNull InputEvent getCharWithBlinkingCursor()
    {
        /* Use the same effectively unlimited wait as the Lua helper. */
        return getCharWithBlinkingCursor(1E10);
    }

    /**
     * Waits up to timeout seconds, returning a KEY_TIMEOUT event on expiry.
     * Keyboard, mouse and system events are returned unchanged; receipt shows the cursor.
     */
    public static @NonNull InputEvent getCharWithBlinkingCursor(double timeout)
    {
        /* Begin visible and alternate the on/off periods until input or expiry. */
        Screen.showCursor();
        boolean shown = true;
        while (timeout > 0)
        {
            double period = Math.min(shown ? BLINK_ON_TIME : BLINK_OFF_TIME, timeout);
            InputEvent event = Screen.getEvent(period);
            if (!(event instanceof KeyInputEvent key) || !key.key().equals("KEY_TIMEOUT"))
            {
                Screen.showCursor();
                return event;
            }
            shown = !shown;
            if (shown)
                Screen.showCursor();
            else
                Screen.hideCursor();
            timeout -= period;
        }
        return new KeyInputEvent("KEY_TIMEOUT");
    }
}
