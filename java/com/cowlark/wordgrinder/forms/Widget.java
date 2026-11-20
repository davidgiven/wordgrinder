/* © 2026 David Given.
 * WordGrinder is licensed under the MIT open source licence. See COPYING.
 */

package com.cowlark.wordgrinder.forms;

import com.cowlark.wordgrinder.Screen;
import java.util.HashMap;
import java.util.Map;
import java.util.function.Function;
import org.jspecify.annotations.NonNull;

/** Base for form widgets. Coordinates and collection indices are zero-based. */
public abstract class Widget
{
    /* Keep requested bounds separate from the bounds assigned by the form. */
    public int x1, y1, x2, y2;
    public int realx1, realy1, realx2, realy2, realwidth, realheight;
    public boolean focusable;
    public boolean focus;

    /* Bind handlers to this instance, independently of its overridable methods. */
    public final @NonNull Map<@NonNull String, @NonNull Function<@NonNull String, @NonNull Action>> keybindings =
            new HashMap<>();

    /* Represent the commands understood by a future form runner. */
    public enum Action
    {
        NOP, CONFIRM, REDRAW, CANCEL
    }

    /* Supply defaults for the optional Lua widget hooks. */
    public void init() {}
    public int calculateHeight() { return 1; }
    public @NonNull Action changed() { return Action.NOP; }
    public @NonNull Action key(Screen.@NonNull KeyInputEvent event) { return Action.NOP; }
    public @NonNull Action click(Screen.@NonNull MouseInputEvent event) { return Action.NOP; }
    public @NonNull Action action(Screen.@NonNull InputEvent event) { return Action.NOP; }

    /* Each concrete widget supplies its own drawing operation. */
    public abstract void draw();
}
