/* © 2026 David Given.
 * WordGrinder is licensed under the MIT open source licence. See COPYING.
 */

package com.cowlark.wordgrinder.forms;

import com.cowlark.wordgrinder.nativeinterface.Screen;
import org.jspecify.annotations.NonNull;

/**
 * A boolean choice toggled with the space key.
 */
public class CheckboxWidget extends Widget
{
    /* Store the selected value and its descriptive label. */
    public boolean value;
    public @NonNull String label = "Checkbox";

    /* Install this widget's keybindings. */
    public CheckboxWidget(@NonNull Screen screen)
    {
        super(screen);
        focusable = true;
        keybindings.put(
                " ", key -> {
                    value = !value;
                    changed();
                    draw();
                    return Action.NOP;
                });
    }

    /* Highlight the choice and place the cursor when focused. */
    @Override
    public void draw()
    {
        screen.write(realx1, realy1, screen.getBoundedString(label, realwidth - 10));
        screen.setBright();
        screen.write(realx2 - 10, realy1, value ? "> YES" : "> NO ");
        screen.setNormal();
        if (focus)
            screen.gotoXY(realx2 - 10, realy1);
    }
}
