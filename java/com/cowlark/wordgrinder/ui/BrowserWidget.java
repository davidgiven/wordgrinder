/* © 2026 David Given.
 * WordGrinder is licensed under the MIT open source licence. See COPYING.
 */

package com.cowlark.wordgrinder.ui;

import static java.lang.Math.max;
import static java.lang.Math.min;

import com.cowlark.wordgrinder.nativeinterface.Screen;
import org.jspecify.annotations.NonNull;
import org.jspecify.annotations.Nullable;
import java.util.ArrayList;
import java.util.List;

/**
 * A scrollable list; cursor and offset are zero-based item indices.
 */
public class BrowserWidget extends Widget<BrowserWidget>
{
    public @NonNull List<@NonNull Item> data = new ArrayList<>();
    public @NonNull String label = "";
    public int cursor;
    public int offset = -1;

    /* Notify subclasses only when the selected item changes. */
    public BrowserWidget()
    {
        focusable = true;
        keybindings.put("KEY_UP", key -> moveTo(max(0, cursor - 1)));
        keybindings.put("KEY_DOWN", key -> moveTo(max(0, min(data.size() - 1, cursor + 1))));
        keybindings.put("KEY_PGUP", key -> moveTo(max(0, cursor - realheight / 2)));
        keybindings.put(
                "KEY_PGDN",
                key -> moveTo(max(0, min(data.size() - 1, cursor + realheight / 2))));
    }

    /**
     * Sets the browser items.
     */
    public @NonNull BrowserWidget setData(@NonNull List<@NonNull Item> data)
    {
        this.data = data;
        return self();
    }

    /**
     * Sets the descriptive label.
     */
    public @NonNull BrowserWidget setLabel(@NonNull String label)
    {
        this.label = label;
        return self();
    }

    /**
     * Sets the zero-based selected item.
     */
    public @NonNull BrowserWidget setCursor(int cursor)
    {
        this.cursor = cursor;
        return self();
    }

    /**
     * Sets the zero-based first visible item; -1 centres the initial selection.
     */
    public @NonNull BrowserWidget setOffset(int offset)
    {
        this.offset = offset;
        return self();
    }

    /* Return the change hook's command to the caller, as in Lua. */
    private @NonNull Action moveTo(int destination)
    {
        if (destination == cursor)
            return Action.NOP;
        cursor = destination;
        draw();
        return changed();
    }

    /* Centre the initial selection, then keep it inside the visible rows. */
    protected void adjustOffset()
    {
        if (offset == -1)
            offset = cursor - realheight / 2;
        offset = min(offset, cursor);
        offset = max(offset, cursor - (realheight - 2));
        offset = min(offset, data.size() - (realheight - 2) - 1);
        offset = max(offset, 0);
    }

    /* Draw the surrounding box using the configured character set. */
    @Override
    public void draw()
    {
        /* Obtain the backend attached by Form.add(). */
        Screen screen = getScreen();

        /* Render the widget using its resolved bounds. */
        int x = realx1;
        int y = realy1;
        int w = realwidth;
        int h = realheight;
        boolean unicode = screen.useUnicode();
        String border = (unicode ? "─" : "-").repeat(w - 2);
        screen.setBright();
        screen.write(x, y, unicode ? "┌" : "+");
        screen.write(x + 1, y, border);
        screen.write(x + w - 1, y, unicode ? "┐" : "+");
        for (int i = 1; i < h; i++)
        {
            screen.write(x, y + i, unicode ? "│" : "|");
            screen.write(x + w - 1, y + i, unicode ? "│" : "|");
        }
        screen.write(x, y + h, unicode ? "└" : "+");
        screen.write(x + 1, y + h, border);
        screen.write(x + w - 1, y + h, unicode ? "┘" : "+");
        screen.setNormal();
        adjustOffset();

        /* Highlight the current item and indicate the visible range on the scrollbar. */
        String space = " ".repeat(w - 2);
        for (int i = 0; i <= h - 2; i++)
        {
            int index = offset + i;
            if (index >= data.size())
                break;
            if (index == cursor)
                screen.setReverse();
            else
                screen.setNormal();
            screen.write(x + 1, y + 1 + i, space);
            screen.write(x + 2, y + 1 + i, screen.getBoundedString(data.get(index).label(), w - 4));
            if (data.size() > h - 2)
            {
                screen.setNormal();
                screen.setBright();
                double fraction = (i + 1.0) * data.size() / (h - 1);
                String mark = fraction >= offset + 1 && fraction <= offset + h - 1 ? "║" : "│";
                screen.write(x + w - 1, y + 1 + i, mark);
            }
            screen.setNormal();
        }
        screen.setNormal();
    }

    /* Browser items carry application data, a display label and an optional key. */
    public record Item(@NonNull String data, @NonNull String label, @Nullable String key)
    {
    }
}
