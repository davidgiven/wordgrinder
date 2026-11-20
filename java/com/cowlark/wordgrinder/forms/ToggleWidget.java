/* © 2026 David Given.
 * WordGrinder is licensed under the MIT open source licence. See COPYING.
 */

package com.cowlark.wordgrinder.forms;

import com.cowlark.wordgrinder.Screen;
import java.util.List;
import org.jspecify.annotations.NonNull;

/** A choice from a nonempty list; value is a zero-based index. */
public class ToggleWidget extends Widget
{
    /* Start with a single default choice. */
    public @NonNull List<@NonNull String> values = List.of("Default");
    public int value;
    public @NonNull String label = "Toggle";

    /* Arrow keys stop at the ends; space cycles through all choices. */
    public ToggleWidget()
    {
        focusable = true;
        keybindings.put("KEY_LEFT", key ->
        {
            if (value != 0)
            {
                value--;
                draw();
            }
            return Action.NOP;
        });
        keybindings.put("KEY_RIGHT", key ->
        {
            if (value != values.size() - 1)
            {
                value++;
                draw();
            }
            return Action.NOP;
        });
        keybindings.put(" ", key ->
        {
            value = (value + 1) % values.size();
            draw();
            return Action.NOP;
        });
    }

    /* Show arrows only where another choice is available. */
    @Override
    public void draw()
    {
        Screen.write(realx1, realy1, " ".repeat(realwidth));
        Screen.write(realx1, realy1, Screen.getBoundedString(label, realwidth - 2));
        String text = (value == 0 ? "  " : "< ") + values.get(value)
                + (value == values.size() - 1 ? "  " : " >");
        Screen.setBright();
        Screen.write(realx2 - 12, realy1, text);
        Screen.setNormal();
        if (focus)
            Screen.gotoXY(realx2 - 10, realy1);
    }
}
