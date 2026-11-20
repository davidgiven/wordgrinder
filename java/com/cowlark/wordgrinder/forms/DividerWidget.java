/* © 2026 David Given.
 * WordGrinder is licensed under the MIT open source licence. See COPYING.
 */

package com.cowlark.wordgrinder.forms;

import com.cowlark.wordgrinder.nativeinterface.Screen;
import org.jspecify.annotations.NonNull;

/**
 * A horizontal divider.
 */
public class DividerWidget extends Widget
{
    /* Supply the drawing backend to the base widget. */
    public DividerWidget(@NonNull Screen screen)
    {
        super(screen);
    }

    /* Draw across the assigned width, matching the Lua divider. */
    @Override
    public void draw()
    {
        screen.write(realx1, realy1, "─".repeat(realwidth));
    }
}
