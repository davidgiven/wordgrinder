/* © 2026 David Given.
 * WordGrinder is licensed under the MIT open source licence. See COPYING.
 */

package com.cowlark.wordgrinder.ui;

import com.cowlark.wordgrinder.nativeinterface.Screen;

/**
 * A boolean choice toggled with the space key.
 */
public class CheckboxWidget extends Widget<CheckboxWidget>
{
    /* Store the selected value and its descriptive label. */
    public boolean value;
    public String label = "Checkbox";

    /* Install this widget's keybindings. */
    public CheckboxWidget()
    {
        focusable = true;
        keybindings.put(
                " ", key -> {
                    value = !value;
                    changed();
                    draw();
                    return Action.NOP;
                });
    }

    /**
     * Sets the checked state.
     */
    public CheckboxWidget setValue(boolean value)
    {
        this.value = value;
        return self();
    }

    /**
     * Sets the descriptive label.
     */
    public CheckboxWidget setLabel(String label)
    {
        this.label = label;
        return self();
    }

    /* Highlight the choice and place the cursor when focused. */
    @Override
    public void draw()
    {
        /* Obtain the backend attached by Form.add(). */
        Screen screen = getScreen();

        /* Render the widget using its resolved bounds. */
        screen.write(realx1, realy1, screen.getBoundedString(label, realwidth - 10));
        screen.setBright();
        screen.write(realx2 - 10, realy1, value ? "> YES" : "> NO ");
        screen.setNormal();
        if (focus)
            screen.gotoXY(realx2 - 10, realy1);
    }
}
