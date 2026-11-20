/* © 2026 David Given.
 * WordGrinder is licensed under the MIT open source licence. See COPYING.
 */

package com.cowlark.wordgrinder.ui;

import com.cowlark.wordgrinder.nativeinterface.Screen;
import java.util.List;

/**
 * A choice from a nonempty list; value is a zero-based index.
 */
public class ToggleWidget extends Widget<ToggleWidget>
{
    /* Start with a single default choice. */
    public List<String> values = List.of("Default");
    public int value;
    public String label = "Toggle";

    /* Arrow keys stop at the ends; space cycles through all choices. */
    public ToggleWidget()
    {
        focusable = true;
        keybindings.put(
                "KEY_LEFT", key -> {
                    if (value != 0)
                    {
                        value--;
                        draw();
                    }
                    return Action.NOP;
                });
        keybindings.put(
                "KEY_RIGHT", key -> {
                    if (value != values.size() - 1)
                    {
                        value++;
                        draw();
                    }
                    return Action.NOP;
                });
        keybindings.put(
                " ", key -> {
                    value = (value + 1) % values.size();
                    draw();
                    return Action.NOP;
                });
    }

    /**
     * Sets the available choices.
     */
    public ToggleWidget setValues(List<String> values)
    {
        this.values = values;
        return self();
    }

    /**
     * Sets the zero-based selected choice.
     */
    public ToggleWidget setValue(int value)
    {
        this.value = value;
        return self();
    }

    /**
     * Sets the descriptive label.
     */
    public ToggleWidget setLabel(String label)
    {
        this.label = label;
        return self();
    }

    /* Show arrows only where another choice is available. */
    @Override
    public void draw()
    {
        /* Obtain the backend attached by Form.add(). */
        Screen screen = getScreen();

        /* Render the widget using its resolved bounds. */
        screen.write(realx1, realy1, " ".repeat(realwidth));
        screen.write(realx1, realy1, screen.getBoundedString(label, realwidth - 2));
        String text = (value == 0 ? "  " : "< ") + values.get(value) +
                (value == values.size() - 1 ? "  " : " >");
        screen.setBright();
        screen.write(realx2 - 12, realy1, text);
        screen.setNormal();
        if (focus)
            screen.gotoXY(realx2 - 10, realy1);
    }
}
