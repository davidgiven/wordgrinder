/* © 2026 David Given.
 * WordGrinder is licensed under the MIT open source licence. See COPYING.
 */

package com.cowlark.wordgrinder.forms;

import com.cowlark.wordgrinder.Screen;

/** A horizontal divider. */
public class DividerWidget extends Widget
{
    /* Draw across the assigned width, matching the Lua divider. */
    @Override
    public void draw()
    {
        Screen.write(realx1, realy1, "─".repeat(realwidth));
    }
}
