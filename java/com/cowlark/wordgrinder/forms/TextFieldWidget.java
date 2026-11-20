/* © 2026 David Given.
 * WordGrinder is licensed under the MIT open source licence. See COPYING.
 */

package com.cowlark.wordgrinder.forms;

import com.cowlark.wordgrinder.nativeinterface.Screen;
import org.jspecify.annotations.NonNull;

/**
 * An editable line. Cursor and offset are UTF-16 indices at code-point boundaries.
 */
public class TextFieldWidget extends Widget<TextFieldWidget>
{
    /* A negative initial cursor means the end of the initial value. */
    public @NonNull String value = "";
    public int cursor = -1;
    public int offset;
    public boolean transientValue;

    /* Bind editing operations to this field. */
    public TextFieldWidget()
    {
        focusable = true;
        keybindings.put(
                "KEY_LEFT", key -> {
                    transientValue = false;
                    if (cursor > 0)
                    {
                        cursor = value.offsetByCodePoints(cursor, -1);
                        draw();
                    }
                    return Action.NOP;
                });
        keybindings.put(
                "KEY_RIGHT", key -> {
                    transientValue = false;
                    if (cursor < value.length())
                    {
                        cursor = value.offsetByCodePoints(cursor, 1);
                        draw();
                    }
                    return Action.NOP;
                });
        keybindings.put(
                "KEY_HOME", key -> {
                    transientValue = false;
                    cursor = 0;
                    draw();
                    return Action.NOP;
                });
        keybindings.put(
                "KEY_END", key -> {
                    transientValue = false;
                    cursor = value.length();
                    draw();
                    return Action.NOP;
                });
        keybindings.put(
                "KEY_BACKSPACE", key -> {
                    discardTransientValue();
                    if (cursor > 0)
                    {
                        int previous = value.offsetByCodePoints(cursor, -1);
                        value = value.substring(0, previous) + value.substring(cursor);
                        cursor = previous;
                        changed();
                        draw();
                    }
                    return Action.NOP;
                });
        keybindings.put(
                "KEY_DELETE", key -> {
                    discardTransientValue();
                    if (cursor < value.length())
                    {
                        value = value.substring(0, cursor) +
                                value.substring(value.offsetByCodePoints(cursor, 1));
                        changed();
                        draw();
                    }
                    return Action.NOP;
                });
        keybindings.put(
                "KEY_^U", key -> {
                    discardTransientValue();
                    cursor = 0;
                    offset = 0;
                    value = "";
                    changed();
                    draw();
                    return Action.NOP;
                });
    }

    /** Sets the editable text. */
    public @NonNull TextFieldWidget setValue(@NonNull String value)
    {
        this.value = value;
        return self();
    }

    /** Sets the UTF-16 cursor index; -1 selects the end during initialisation. */
    public @NonNull TextFieldWidget setCursor(int cursor)
    {
        this.cursor = cursor;
        return self();
    }

    /** Sets the UTF-16 index of the first visible code point. */
    public @NonNull TextFieldWidget setOffset(int offset)
    {
        this.offset = offset;
        return self();
    }

    /** Sets whether the initial text is replaced by the first edit. */
    public @NonNull TextFieldWidget setTransientValue(boolean transientValue)
    {
        this.transientValue = transientValue;
        return self();
    }

    /* Preserve explicit cursor positions across redraws. */
    @Override
    public void init()
    {
        if (cursor < 0)
            cursor = value.length();
    }

    /* Replace transient initial text on the first editing operation. */
    private void discardTransientValue()
    {
        if (transientValue)
        {
            value = "";
            cursor = 0;
            offset = 0;
            transientValue = false;
        }
    }

    /* Scroll by whole code points until the cursor fits in the field. */
    @Override
    public void draw()
    {
        /* Obtain the backend attached by Form.add(). */
        Screen screen = getScreen();

        /* Render the widget using its resolved bounds. */
        screen.setBright();
        screen.write(realx1, realy1 + 1, (screen.useUnicode() ? "▔" : " ").repeat(realwidth));
        screen.write(realx1, realy1, " ".repeat(realwidth));
        screen.setNormal();
        if (cursor < offset)
            offset = cursor;
        while (offset < cursor &&
                screen.getStringWidth(value.substring(offset, cursor)) > realwidth)
            offset = value.offsetByCodePoints(offset, 1);

        /* Highlight transient text and position the cursor by terminal cell width. */
        String text = screen.getBoundedString(value.substring(offset), realwidth);
        screen.setBright();
        if (transientValue)
            screen.setReverse();
        screen.write(realx1, realy1, text);
        screen.setNormal();
        if (focus)
            screen.gotoXY(realx1 + screen.getStringWidth(value.substring(offset, cursor)), realy1);
    }

    /* Convert a mouse column into a code-point boundary, including wide characters. */
    @Override
    public @NonNull Action click(Screen.@NonNull MouseInputEvent event)
    {
        Screen screen = getScreen();
        int column = event.x() - realx1;
        if (column < 0)
            return Action.NOP;
        int position = offset;
        int width = 0;
        while (position < value.length())
        {
            int next = value.offsetByCodePoints(position, 1);
            int nextWidth = screen.getStringWidth(value.substring(position, next));
            if (width + nextWidth > column)
                break;
            width += nextWidth;
            position = next;
        }
        if (column > width && position == value.length())
            return Action.NOP;
        cursor = position;
        return Action.REDRAW;
    }

    /* Insert character events; leave unhandled symbolic keys alone. */
    @Override
    public @NonNull Action key(Screen.@NonNull KeyInputEvent event)
    {
        String text = event.key();
        if (!text.startsWith("KEY_"))
        {
            discardTransientValue();
            value = value.substring(0, cursor) + text + value.substring(cursor);
            cursor += text.length();
            changed();
            draw();
        }
        return Action.NOP;
    }
}
