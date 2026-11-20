/* © 2026 David Given.
 * WordGrinder is licensed under the MIT open source licence. See COPYING.
 */

package com.cowlark.wordgrinder.ui;

import com.cowlark.wordgrinder.nativeinterface.Screen;
import org.jspecify.annotations.NonNull;

/**
 * A single line of aligned text.
 */
public class LabelWidget extends Widget<LabelWidget>
{
    public @NonNull Alignment align = Alignment.CENTRE;
    public @NonNull String value = "";

    /**
     * Sets the text alignment.
     */
    public @NonNull LabelWidget setAlign(@NonNull Alignment align)
    {
        this.align = align;
        return self();
    }

    /**
     * Sets the displayed text.
     */
    public @NonNull LabelWidget setValue(@NonNull String value)
    {
        this.value = value;
        return self();
    }

    /* Clear the field before drawing its aligned contents. */
    @Override
    public void draw()
    {
        /* Obtain the backend attached by Form.add(). */
        Screen screen = getScreen();

        /* Render the widget using its resolved bounds. */
        int offset = switch (align)
        {
            case LEFT -> 0;
            case RIGHT -> realwidth - screen.getStringWidth(value);
            case CENTRE -> Math.floorDiv(realwidth - screen.getStringWidth(value), 2);
        };
        screen.write(realx1, realy1, " ".repeat(realwidth));
        screen.write(realx1 + offset, realy1, value);
    }

    /* Labels default to centred text. */
    public enum Alignment
    {LEFT, RIGHT, CENTRE}
}
