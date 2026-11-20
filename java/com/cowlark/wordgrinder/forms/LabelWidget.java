/* © 2026 David Given.
 * WordGrinder is licensed under the MIT open source licence. See COPYING.
 */

package com.cowlark.wordgrinder.forms;

import com.cowlark.wordgrinder.nativeinterface.Screen;
import org.jspecify.annotations.NonNull;

/**
 * A single line of aligned text.
 */
public class LabelWidget extends Widget
{
    public @NonNull Alignment align = Alignment.CENTRE;
    public @NonNull String value = "";
    /* Supply the drawing backend to the base widget. */
    public LabelWidget(@NonNull Screen screen)
    {
        super(screen);
    }

    /* Clear the field before drawing its aligned contents. */
    @Override
    public void draw()
    {
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
