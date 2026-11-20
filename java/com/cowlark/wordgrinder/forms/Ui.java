/* © 2026 David Given.
 * WordGrinder is licensed under the MIT open source licence. See COPYING.
 */

package com.cowlark.wordgrinder.forms;

import com.cowlark.wordgrinder.nativeinterface.Screen;
import com.cowlark.wordgrinder.nativeinterface.Screen.InputEvent;
import com.cowlark.wordgrinder.nativeinterface.Screen.KeyInputEvent;
import org.jspecify.annotations.NonNull;
import org.jspecify.annotations.Nullable;

/**
 * Screen helpers shared by forms, translated from ui.lua and redraw.lua.
 */
public final class Ui
{
    /* Match the cursor timings declared in the Lua prologue, in seconds. */
    public static final double BLINK_ON_TIME = 0.8;
    public static final double BLINK_OFF_TIME = 0.53;

    /* Draw and read input through the supplied screen backend. */
    private final @NonNull Screen screen;
    /* Retain the UI-wide quit flag and the Light palette's default control colours. */
    private boolean quitting;
    private float @NonNull [] controlForeground = {0.2f, 0.2f, 0.2f};
    private float @NonNull [] controlBackground = {0.85f, 0.85f, 0.85f};
    public Ui(@NonNull Screen screen)
    {
        this.screen = screen;
    }

    /**
     * Creates a new form sharing this UI and its screen.
     */
    public @NonNull Form newForm()
    {
        return new Form(this);
    }

    /**
     * Returns the injected screen shared by forms and their widgets.
     */
    public @NonNull Screen getScreen()
    {
        return screen;
    }

    /**
     * Requests that all modal form loops using this UI stop.
     */
    public void requestQuit()
    {
        quitting = true;
    }

    /**
     * Cancels a previous quit request.
     */
    public void cancelQuit()
    {
        quitting = false;
    }

    /**
     * Reports whether the application has requested shutdown.
     */
    public boolean isQuitting()
    {
        return quitting;
    }

    /**
     * Sets the RGB colours used when drawing forms. Components range from 0 to 1.
     */
    public void setControlColours(float @NonNull [] foreground, float @NonNull [] background)
    {
        controlForeground = foreground.clone();
        controlBackground = background.clone();
    }

    /* Apply the current control colours before drawing a form. */
    void setControlColour()
    {
        screen.setColour(controlForeground, controlBackground);
    }

    /**
     * Draws a reversed status line on the bottom screen row.
     */
    public void drawStatusLine(@NonNull String text)
    {
        /* Query the current size rather than retaining document redraw state. */
        int[] size = screen.getScreenSize();
        screen.setReverse();
        screen.clearArea(0, size[1] - 1, size[0] - 1, size[1] - 1);
        screen.write(0, size[1] - 1, text);
        screen.setNormal();
    }

    /**
     * Draws and clears a box with an interior of width by height cells.
     * The top-left corner is (x, y); the interior starts at (x + 1, y + 1).
     * As in Lua, a column outside each vertical border is also cleared.
     */
    public void drawBox(int x, int y, int width, int height)
    {
        /* Draw the corners and horizontal borders in the selected character set. */
        boolean unicode = screen.useUnicode();
        String border = (unicode ? "─" : "-").repeat(width);
        String space = " ".repeat(width);
        screen.write(x - 1, y, unicode ? " ┌" : " +");
        screen.write(x + width + 1, y, unicode ? "┐ " : "+ ");
        screen.write(x - 1, y + height + 1, unicode ? " └" : " +");
        screen.write(x + width + 1, y + height + 1, unicode ? "┘ " : "+ ");
        screen.write(x + 1, y, border);
        screen.write(x + 1, y + height + 1, border);

        /* Clear the interior and draw its vertical borders. */
        for (int row = y + 1; row <= y + height; row++)
        {
            screen.write(x - 1, row, unicode ? " │" : " |");
            screen.write(x + width + 1, row, unicode ? "│ " : "| ");
            screen.write(x + 1, row, space);
        }
    }

    /**
     * Clips text to the field's cell width and centres it without clearing the field.
     */
    public void centreInField(int x, int y, int width, @NonNull String text)
    {
        /* Align using terminal cell widths rather than Java string lengths. */
        String bounded = screen.getBoundedString(text, width);
        int offset = Math.floorDiv(width - screen.getStringWidth(bounded), 2);
        screen.write(x + offset, y, bounded);
    }

    /**
     * Clips text and aligns it to the left without clearing the field.
     */
    public void lAlignInField(int x, int y, int width, @NonNull String text)
    {
        /* Clipping preserves complete Unicode code points. */
        screen.write(x, y, screen.getBoundedString(text, width));
    }

    /**
     * Clips text and aligns it to the right without clearing the field.
     */
    public void rAlignInField(int x, int y, int width, @NonNull String text)
    {
        /* Measure the clipped text so it ends at the field's right edge. */
        String bounded = screen.getBoundedString(text, width);
        screen.write(x + width - screen.getStringWidth(bounded), y, bounded);
    }

    /**
     * Draws a bright box with a centred title on its top border.
     */
    public void drawTitledBox(int x, int y, int width, int height, @NonNull String title)
    {
        /* A missing subtitle leaves the lower border uninterrupted. */
        drawTitledBox(x, y, width, height, title, null);
    }

    /**
     * Draws a titled box with an optional bold subtitle on its bottom border.
     */
    public void drawTitledBox(
            int x,
            int y,
            int width,
            int height,
            @NonNull String title,
            @Nullable String subtitle)
    {
        /* Restore normal attributes after drawing both border captions. */
        screen.setBright();
        drawBox(x, y, width, height);
        centreInField(x + 1, y, width, title);
        if (subtitle != null)
        {
            screen.setBold();
            centreInField(x + 1, y + height + 1, width, subtitle);
        }
        screen.setNormal();
    }

    /**
     * Displays a centred boxed message immediately, without waiting for input.
     */
    public void immediateMessage(@NonNull String text)
    {
        /* Match the Lua message's padding and placement on the current screen. */
        int[] size = screen.getScreenSize();
        int width = screen.getStringWidth(text);
        int x = Math.floorDiv(size[0] - width, 2);
        int y = Math.floorDiv(size[1], 2);
        drawBox(x - 2, y - 1, width + 2, 1);
        screen.write(x, y, text);
        screen.sync();
    }

    /**
     * Waits for an input event while blinking the cursor.
     */
    public @NonNull InputEvent getCharWithBlinkingCursor()
    {
        /* Use the same effectively unlimited wait as the Lua helper. */
        return getCharWithBlinkingCursor(1E10);
    }

    /**
     * Waits up to timeout seconds, returning a KEY_TIMEOUT event on expiry.
     * Keyboard, mouse and system events are returned unchanged; receipt shows the cursor.
     */
    public @NonNull InputEvent getCharWithBlinkingCursor(double timeout)
    {
        /* Begin visible and alternate the on/off periods until input or expiry. */
        screen.showCursor();
        boolean shown = true;
        while (timeout > 0)
        {
            double period = Math.min(shown ? BLINK_ON_TIME : BLINK_OFF_TIME, timeout);
            InputEvent event = screen.getEvent(period);
            if (!(event instanceof KeyInputEvent key) || !key.key().equals("KEY_TIMEOUT"))
            {
                screen.showCursor();
                return event;
            }
            shown = !shown;
            if (shown)
                screen.showCursor();
            else
                screen.hideCursor();
            timeout -= period;
        }
        return new KeyInputEvent("KEY_TIMEOUT");
    }
}
