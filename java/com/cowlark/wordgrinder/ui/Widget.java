/* © 2026 David Given.
 * WordGrinder is licensed under the MIT open source licence. See COPYING.
 */

package com.cowlark.wordgrinder.ui;

import com.cowlark.wordgrinder.nativeinterface.Screen;
import org.jspecify.annotations.NonNull;
import org.jspecify.annotations.Nullable;
import java.util.HashMap;
import java.util.Map;
import java.util.function.Function;

/**
 * Base for form widgets. Coordinates and collection indices are zero-based.
 * The self type preserves concrete widget setters in fluent configuration chains.
 */
public abstract class Widget<T extends Widget<T>>
{
    /* Bind handlers to this instance, independently of its overridable methods. */
    public final @NonNull Map<@NonNull String, @NonNull Function<@NonNull String, @NonNull Action>>
            keybindings = new HashMap<>();
    /* Keep requested bounds separate from the bounds assigned by the form. */
    public int x1, y1, x2, y2;
    public int realx1, realy1, realx2, realy2, realwidth, realheight;
    public boolean focusable;
    public boolean focus;
    /* The owning form attaches its screen when this widget is added. */
    private @Nullable Screen screen;

    /* Preserve the concrete widget type through inherited fluent setters. */
    @SuppressWarnings("unchecked")
    protected final @NonNull T self()
    {
        return (T) this;
    }

    /* Only the form supplies the backend; construction and configuration need none. */
    final void attachScreen(@NonNull Screen screen)
    {
        this.screen = screen;
    }

    /**
     * Returns the owning form's screen; drawing requires the widget to have been added.
     */
    protected final @NonNull Screen getScreen()
    {
        if (screen == null)
            throw new IllegalStateException("Add the widget to a form before drawing it");
        return screen;
    }

    /**
     * Sets the requested left bound.
     */
    public @NonNull T setX1(int x1)
    {
        this.x1 = x1;
        return self();
    }

    /**
     * Sets the requested top bound.
     */
    public @NonNull T setY1(int y1)
    {
        this.y1 = y1;
        return self();
    }

    /**
     * Sets the requested right bound.
     */
    public @NonNull T setX2(int x2)
    {
        this.x2 = x2;
        return self();
    }

    /**
     * Sets the requested bottom bound.
     */
    public @NonNull T setY2(int y2)
    {
        this.y2 = y2;
        return self();
    }

    /**
     * Sets whether the widget can receive focus.
     */
    public @NonNull T setFocusable(boolean focusable)
    {
        this.focusable = focusable;
        return self();
    }

    /**
     * Sets the requested bounds; negative values count back from the form's size.
     */
    public @NonNull T setBounds(int x1, int y1, int x2, int y2)
    {
        return setX1(x1).setY1(y1).setX2(x2).setY2(y2);
    }

    /**
     * Installs or replaces a keybinding on this widget.
     */
    public @NonNull T setKeybinding(
            @NonNull String key,
            @NonNull Function<@NonNull String, @NonNull Action> action)
    {
        keybindings.put(key, action);
        return self();
    }

    /* Supply defaults for the optional Lua widget hooks. */
    public void init()
    {
    }

    public int calculateHeight()
    {
        return 1;
    }

    public @NonNull Action changed()
    {
        return Action.NOP;
    }

    public @NonNull Action key(Screen.@NonNull KeyInputEvent event)
    {
        return Action.NOP;
    }

    /**
     * Returns null when no click handler is installed, allowing mouse fallback.
     */
    public @Nullable Action click(Screen.@NonNull MouseInputEvent event)
    {
        return null;
    }

    /**
     * Handles other mouse events; null requests the form's default redraw.
     */
    public @Nullable Action mouse(Screen.@NonNull MouseInputEvent event)
    {
        return null;
    }

    public @NonNull Action action(Screen.@NonNull InputEvent event)
    {
        return Action.NOP;
    }

    /* Each concrete widget supplies its own drawing operation. */
    public abstract void draw();

    /* Represent the commands understood by a future form runner. */
    public enum Action
    {
        NOP, CONFIRM, REDRAW, CANCEL
    }
}
