/* © 2026 David Given.
 * WordGrinder is licensed under the MIT open source licence. See COPYING.
 */

package com.cowlark.wordgrinder.forms;

import com.cowlark.wordgrinder.Screen;
import java.util.ArrayList;
import java.util.List;
import org.jspecify.annotations.NonNull;
import org.jspecify.annotations.Nullable;

/** A scrollable list; cursor and offset are zero-based item indices. */
public class BrowserWidget extends Widget
{
    /* Browser items carry application data, a display label and an optional key. */
    public record Item(@NonNull String data, @NonNull String label, @Nullable String key) {}
    public @NonNull List<@NonNull Item> data = new ArrayList<>();
    public @NonNull String label = "";
    public int cursor;
    public int offset = -1;

    /* Notify subclasses only when the selected item changes. */
    public BrowserWidget()
    {
        focusable = true;
        keybindings.put("KEY_UP", key -> moveTo(Math.max(0, cursor - 1)));
        keybindings.put("KEY_DOWN", key -> moveTo(Math.max(0, Math.min(data.size() - 1, cursor + 1))));
        keybindings.put("KEY_PGUP", key -> moveTo(Math.max(0, cursor - realheight / 2)));
        keybindings.put("KEY_PGDN", key -> moveTo(Math.max(0, Math.min(data.size() - 1, cursor + realheight / 2))));
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
        offset = Math.min(offset, cursor);
        offset = Math.max(offset, cursor - (realheight - 2));
        offset = Math.min(offset, data.size() - (realheight - 2) - 1);
        offset = Math.max(offset, 0);
    }

    /* Draw the surrounding box using the configured character set. */
    @Override
    public void draw()
    {
        int x = realx1;
        int y = realy1;
        int w = realwidth;
        int h = realheight;
        boolean unicode = Screen.useUnicode();
        String border = (unicode ? "─" : "-").repeat(w - 2);
        Screen.setBright();
        Screen.write(x, y, unicode ? "┌" : "+");
        Screen.write(x + 1, y, border);
        Screen.write(x + w - 1, y, unicode ? "┐" : "+");
        for (int i = 1; i < h; i++)
        {
            Screen.write(x, y + i, unicode ? "│" : "|");
            Screen.write(x + w - 1, y + i, unicode ? "│" : "|");
        }
        Screen.write(x, y + h, unicode ? "└" : "+");
        Screen.write(x + 1, y + h, border);
        Screen.write(x + w - 1, y + h, unicode ? "┘" : "+");
        Screen.setNormal();
        adjustOffset();

        /* Highlight the current item and indicate the visible range on the scrollbar. */
        String space = " ".repeat(w - 2);
        for (int i = 0; i <= h - 2; i++)
        {
            int index = offset + i;
            if (index >= data.size())
                break;
            if (index == cursor)
                Screen.setReverse();
            else
                Screen.setNormal();
            Screen.write(x + 1, y + 1 + i, space);
            Screen.write(x + 2, y + 1 + i, Screen.getBoundedString(data.get(index).label(), w - 4));
            if (data.size() > h - 2)
            {
                Screen.setNormal();
                Screen.setBright();
                double fraction = (i + 1.0) * data.size() / (h - 1);
                String mark = fraction >= offset + 1 && fraction <= offset + h - 1 ? "║" : "│";
                Screen.write(x + w - 1, y + 1 + i, mark);
            }
            Screen.setNormal();
        }
        Screen.setNormal();
    }
}
