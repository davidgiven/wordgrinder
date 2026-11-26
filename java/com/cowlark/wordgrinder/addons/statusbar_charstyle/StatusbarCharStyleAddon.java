/* © 2015 David Given.
 * WordGrinder is licensed under the MIT open source licence. See the COPYING
 * file in this distribution for the full text.
 */
package com.cowlark.wordgrinder.addons.statusbar_charstyle;

import com.cowlark.wordgrinder.document.Document;
import com.cowlark.wordgrinder.document.Word;
import com.cowlark.wordgrinder.eventbus.BuildStatusBarEvent;
import com.cowlark.wordgrinder.eventbus.EventBus;
import com.cowlark.wordgrinder.eventbus.MovedEvent;
import java.util.function.Supplier;

public final class StatusbarCharStyleAddon
{
    /* Retain the typing style until the cursor moves or a command overrides it. */
    private int style;

    public StatusbarCharStyleAddon(EventBus eventBus, Supplier<Document> currentDocument)
    {
        /* Build the status bar. */
        eventBus.addEventListener(BuildStatusBarEvent.class, this::buildStatusBar);

        /* Update the style whenever the cursor moves. */
        eventBus.addEventListener(MovedEvent.class, event -> style = styleToLeftOfCursor(currentDocument.get()));
    }

    /* Allow the current style to be overridden and fetched. */
    public void setCurrentStyleHint(int styleXor, int styleAnd)
    {
        style = (style ^ styleXor) & styleAnd;
    }

    public int getCurrentStyleHint()
    {
        return style;
    }

    /* Display the active italic, bold and underline bits in Lua's order. */
    private void buildStatusBar(BuildStatusBarEvent event)
    {
        String text = ((style & Word.ITALIC) != 0 ? "I" : ".")
                + ((style & Word.BOLD) != 0 ? "B" : ".")
                + ((style & Word.UNDERLINE) != 0 ? "U" : ".");
        event.fields.add(new BuildStatusBarEvent.Field(110, text));
    }

    /* At the beginning of a word, read the style from the end of its predecessor. */
    private static int styleToLeftOfCursor(Document document)
    {
        var words = document.paragraphs.get(document.cursorParagraph).words();
        int word = document.cursorWord;
        int offset = document.cursorOffset;
        if (words.isEmpty() || (word == 0 && offset == 0))
            return 0;

        if (offset == 0)
        {
            String previous = words.get(word - 1);
            offset = previous.isEmpty() ? 0 : previous.offsetByCodePoints(previous.length(), -1);
            return Word.getStyleFromWord(previous, offset);
        }
        return Word.getStyleFromWord(words.get(word), offset);
    }
}
