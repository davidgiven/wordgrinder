/* © 2026 David Given.
 * WordGrinder is licensed under the MIT open source licence. See COPYING.
 */

package com.cowlark.wordgrinder.forms;

import com.cowlark.wordgrinder.nativeinterface.Screen;

/**
 * A horizontal divider.
 */
public class DividerWidget extends Widget<DividerWidget>
{
    /* Draw across the assigned width, matching the Lua divider. */
    @Override
    public void draw()
    {
        /* Obtain the backend attached by Form.add(). */
        Screen screen = getScreen();

        /* Render the widget using its resolved bounds. */
        screen.write(realx1, realy1, "─".repeat(realwidth));
    }
}
