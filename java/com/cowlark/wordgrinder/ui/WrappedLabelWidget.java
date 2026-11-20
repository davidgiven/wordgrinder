/* © 2026 David Given.
 * WordGrinder is licensed under the MIT open source licence. See COPYING.
 */

package com.cowlark.wordgrinder.ui;

import com.cowlark.wordgrinder.Paragraph;
import com.cowlark.wordgrinder.Word;
import com.cowlark.wordgrinder.document.DocumentStyle;
import com.cowlark.wordgrinder.eventbus.EventBus;
import com.google.common.collect.ImmutableList;
import org.jspecify.annotations.NonNull;

/** A label laid out and drawn as an ordinary paragraph, without DrawWord events. */
public class WrappedLabelWidget extends Widget<WrappedLabelWidget>
{
    /* Label paragraphs have no document indentation or heading attributes. */
    private static final @NonNull DocumentStyle STYLE = new DocumentStyle(
            "Paragraph", "P", 0, 0, null, null, null, null, null, null);

    /* Retain rendering collaborators; Form.add() supplies the screen separately. */
    private final @NonNull Word wordRenderer;
    private final @NonNull EventBus eventBus;
    public @NonNull String value = "";
    public boolean fullStopSpaces;

    public WrappedLabelWidget(@NonNull Word wordRenderer, @NonNull EventBus eventBus)
    {
        this.wordRenderer = wordRenderer;
        this.eventBus = eventBus;
    }

    /** Sets the text to wrap, preserving any embedded word styles. */
    public @NonNull WrappedLabelWidget setValue(@NonNull String value)
    {
        this.value = value;
        return self();
    }

    /** Selects double spacing after full stops without consulting document preferences. */
    public @NonNull WrappedLabelWidget setFullStopSpaces(boolean fullStopSpaces)
    {
        this.fullStopSpaces = fullStopSpaces;
        return self();
    }

    /* Split on exactly the whitespace recognised by Lua's ParseStringIntoWords. */
    private @NonNull Paragraph paragraph()
    {
        ImmutableList.Builder<String> words = ImmutableList.builder();
        int start = -1;
        for (int i = 0; i <= value.length(); i++)
        {
            char character = i < value.length() ? value.charAt(i) : ' ';
            boolean separator = character == ' ' || character == '\t'
                    || character == '\r' || character == '\n';
            if (separator && start >= 0)
            {
                words.add(value.substring(start, i));
                start = -1;
            }
            else if (!separator && start < 0)
                start = i;
        }

        /* Lua represents whitespace-only input as a single empty word. */
        ImmutableList<String> content = words.build();
        if (content.isEmpty())
            content = ImmutableList.of("");
        return new Paragraph(getScreen(), wordRenderer, eventBus, STYLE, content);
    }

    /* Let stretchy forms measure the same layout that drawing will use. */
    @Override
    public int calculateHeight()
    {
        return paragraph().wrap(realwidth, fullStopSpaces).lines().size();
    }

    /* Draw every wrapped line without invoking spellcheckers or other DrawWord listeners. */
    @Override
    public void draw()
    {
        Paragraph paragraph = paragraph();
        Paragraph.WrapData layout = paragraph.wrap(realwidth, fullStopSpaces);
        for (int line = 0; line < layout.lines().size(); line++)
            paragraph.renderLine(layout.lines().get(line), realx1, realy1 + line, false);
    }
}
