/* © 2026 David Given.
 * WordGrinder is licensed under the MIT open source licence. See COPYING.
 */

package com.cowlark.wordgrinder.forms;

import com.cowlark.wordgrinder.forms.Widget.Action;
import com.cowlark.wordgrinder.nativeinterface.Screen;
import com.cowlark.wordgrinder.nativeinterface.Screen.InputEvent;
import com.cowlark.wordgrinder.nativeinterface.Screen.KeyInputEvent;
import com.cowlark.wordgrinder.nativeinterface.Screen.MouseInputEvent;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.function.BiFunction;
import org.jspecify.annotations.NonNull;
import org.jspecify.annotations.Nullable;

/**
 * A modal form, translated from Form.Run in forms.lua.
 * Build with new Form(ui).setTitle("Title").add(widget).on("KEY_RETURN", Action.CONFIRM).run().
 * Coordinates are relative to the form; negative bounds count back from its size.
 */
public final class Form
{
    /* Keep the UI and its screen together with the widgets and form-level bindings. */
    private final @NonNull Ui ui;
    private final @NonNull Screen screen;
    private final @NonNull List<@NonNull Widget<?>> widgets = new ArrayList<>();
    private final @NonNull Map<@NonNull String,
            @NonNull BiFunction<@NonNull Form, @NonNull String, @NonNull Action>> actions = new HashMap<>();

    /* Missing dimensions select the Lua 'large' size; focus is selected on first draw. */
    private @NonNull String title = "";
    private @Nullable Integer width;
    private @Nullable Integer height;
    private boolean stretchy;
    private boolean transientDisplay;
    private @Nullable Widget<?> focus;
    private @Nullable Runnable redraw;
    private @Nullable String helpText;

    /* Obtain the same injected screen used by the UI drawing helpers. */
    public Form(@NonNull Ui ui)
    {
        this.ui = ui;
        screen = ui.getScreen();
    }

    /** Appends a widget, preserving drawing, hit-testing and focus order. */
    public @NonNull Form add(@NonNull Widget<?> widget)
    {
        widget.attachScreen(screen);
        widgets.add(widget);
        return this;
    }

    /** Sets the title drawn on the top border. */
    public @NonNull Form setTitle(@NonNull String title)
    {
        this.title = title;
        return this;
    }

    /** Sets the interior width in cells; by default it is six sevenths of the screen. */
    public @NonNull Form setWidth(int width)
    {
        this.width = width;
        return this;
    }

    /** Sets the interior height in cells; by default it is five sixths of the screen. */
    public @NonNull Form setHeight(int height)
    {
        this.height = height;
        return this;
    }

    /** Sets both fixed dimensions. */
    public @NonNull Form setSize(int width, int height)
    {
        return setWidth(width).setHeight(height);
    }

    /** Adds the calculated height of the first widget spanning positive to negative rows. */
    public @NonNull Form setStretchy(boolean stretchy)
    {
        this.stretchy = stretchy;
        return this;
    }

    /** Draws optional help text beneath the widgets, inside an extra row of the box. */
    public @NonNull Form setHelpText(@Nullable String helpText)
    {
        this.helpText = helpText;
        return this;
    }

    /** Supplies the backdrop redraw operation, called before laying out the form. */
    public @NonNull Form setRedraw(@NonNull Runnable redraw)
    {
        this.redraw = redraw;
        return this;
    }

    /** Selects a widget already added to the form as its initial focus. */
    public @NonNull Form setFocus(@NonNull Widget<?> widget)
    {
        if (!widgets.contains(widget))
            throw new IllegalArgumentException("The focused widget must belong to the form");
        focus = widget;
        return this;
    }

    /** Binds a key to a form command. Widget bindings take precedence. */
    public @NonNull Form on(@NonNull String key, @NonNull Action action)
    {
        return on(key, (form, pressedKey) -> action);
    }

    /** Binds a key to a callback receiving this form and the key name. */
    public @NonNull Form on(
            @NonNull String key,
            @NonNull BiFunction<@NonNull Form, @NonNull String, @NonNull Action> action)
    {
        actions.put(key, action);
        return this;
    }

    /** Redraws transient screen contents after the next input event, before dispatching it. */
    public @NonNull Form invalidate()
    {
        transientDisplay = true;
        return this;
    }

    /** Runs the form until confirmation, cancellation or a UI quit request. */
    public boolean run()
    {
        /* Draw once before entering the modal input loop. */
        draw();
        while (!ui.isQuitting())
        {
            screen.hideCursor();
            InputEvent event = focus != null ? ui.getCharWithBlinkingCursor() : screen.getEvent();
            if (transientDisplay)
                draw();

            /* Handle backend lifecycle events before user bindings. */
            if (event instanceof KeyInputEvent key)
            {
                if (key.key().equals("KEY_RESIZE"))
                    draw();
                if (key.key().equals("KEY_QUIT"))
                {
                    ui.requestQuit();
                    return false;
                }
            }

            /* Execute the selected command, leaving NOP and unhandled events in the loop. */
            Action action = event instanceof MouseInputEvent mouse ? mouse(mouse) : key((KeyInputEvent) event);
            if (action == Action.CANCEL)
                return false;
            if (action == Action.CONFIRM)
                return true;
            if (action == Action.REDRAW)
                draw();
        }
        return false;
    }

    /* Negative widget coordinates are measured from the form's far edge. */
    private static int resolveSize(int size, int bound)
    {
        return size < 0 ? size + bound : size;
    }

    /* Recalculate geometry and initialise widgets whenever the form is redrawn. */
    private void draw()
    {
        int[] screenSize = screen.getScreenSize();
        if (focus == null)
        {
            for (Widget<?> widget : widgets)
            {
                if (widget.focusable)
                {
                    focus = widget;
                    break;
                }
            }
        }
        for (Widget<?> widget : widgets)
            widget.init();
        if (redraw != null)
            redraw.run();

        /* Size stretchy forms using the first widget which spans the flexible region. */
        int realwidth = width != null ? width : screenSize[0] * 6 / 7;
        int realheight = height != null ? height : screenSize[1] * 5 / 6;
        if (stretchy)
        {
            for (Widget<?> widget : widgets)
            {
                if (widget.y1 > 0 && widget.y2 < 0)
                {
                    widget.realx1 = resolveSize(widget.x1, realwidth);
                    widget.realx2 = resolveSize(widget.x2, realwidth);
                    widget.realwidth = widget.realx2 - widget.realx1;
                    realheight += widget.calculateHeight();
                    break;
                }
            }
        }

        /* Centre the form and resolve the requested bounds of each widget. */
        int realx = Math.floorDiv(screenSize[0] - realwidth, 2);
        int realy = Math.floorDiv(screenSize[1] - realheight, 2);
        for (Widget<?> widget : widgets)
        {
            widget.realx1 = resolveSize(widget.x1, realwidth) + realx;
            widget.realy1 = resolveSize(widget.y1, realheight) + realy;
            widget.realx2 = resolveSize(widget.x2, realwidth) + realx;
            widget.realy2 = resolveSize(widget.y2, realheight) + realy;
            widget.realwidth = widget.realx2 - widget.realx1;
            widget.realheight = widget.realy2 - widget.realy1;
        }

        /* Draw the frame, optional help row and all widgets in the control colours. */
        ui.setControlColour();
        ui.drawTitledBox(realx - 1, realy - 1, realwidth,
                realheight + (helpText != null ? 1 : 0), title);
        if (helpText != null)
            ui.centreInField(realx, realy + realheight, realwidth, "<" + helpText + ">");
        screen.gotoXY(screenSize[0] - 1, screenSize[1] - 1);
        for (Widget<?> widget : widgets)
        {
            widget.focus = widget == focus;
            widget.draw();
        }
        transientDisplay = false;
    }

    /* Search widget bindings, cancellation, form bindings, navigation, then generic keys. */
    private @NonNull Action key(@NonNull KeyInputEvent event)
    {
        String key = event.key();
        if (focus != null)
        {
            var binding = focus.keybindings.get(key);
            if (binding != null)
                return binding.apply(key);
        }
        if (key.equals("KEY_^C") || key.equals("KEY_ESCAPE"))
            return Action.CANCEL;
        var binding = actions.get(key);
        if (binding != null)
            return binding.apply(this, key);
        if (key.equals("KEY_UP"))
            return moveFocus(-1);
        if (key.equals("KEY_DOWN"))
            return moveFocus(1);
        return focus != null ? focus.key(event) : Action.NOP;
    }

    /* Wrap around the widget list while skipping widgets which cannot take focus. */
    private @NonNull Action moveFocus(int direction)
    {
        if (focus == null)
            return Action.NOP;
        int start = widgets.indexOf(focus);
        for (int step = 1; step < widgets.size(); step++)
        {
            Widget<?> widget = widgets.get(Math.floorMod(start + direction * step, widgets.size()));
            if (widget.focusable)
            {
                focus = widget;
                return Action.REDRAW;
            }
        }
        return Action.NOP;
    }

    /* Hit-test in insertion order; button events may transfer focus before dispatch. */
    private @NonNull Action mouse(@NonNull MouseInputEvent event)
    {
        for (Widget<?> widget : widgets)
        {
            if (event.x() >= widget.realx1 && event.x() <= widget.realx2
                    && event.y() >= widget.realy1 && event.y() <= widget.realy2)
            {
                Action action = null;
                if (event.b() && widget.focusable)
                {
                    focus = widget;
                    action = widget.click(event);
                }
                if (action == null)
                    action = widget.mouse(event);
                return action != null ? action : Action.REDRAW;
            }
        }
        return Action.NOP;
    }
}
