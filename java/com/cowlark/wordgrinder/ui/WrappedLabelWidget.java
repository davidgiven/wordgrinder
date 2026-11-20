/* © 2026 David Given.
 * WordGrinder is licensed under the MIT open source licence. See COPYING.
 */

package com.cowlark.wordgrinder.ui;

import com.cowlark.wordgrinder.document.DocumentStyle;
import com.cowlark.wordgrinder.document.Paragraph;
import com.cowlark.wordgrinder.document.Word;
import com.cowlark.wordgrinder.eventbus.EventBus;
import org.jspecify.annotations.NonNull;

/**
 * A label laid out and drawn as an ordinary paragraph, without DrawWord events.
 */
public class WrappedLabelWidget extends Widget<WrappedLabelWidget>
{
    /* Label paragraphs have no document indentation or heading attributes. */
    private static final @NonNull DocumentStyle STYLE =
            new DocumentStyle("Paragraph", "P", 0, 0, null, null, null, null, null, null);

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

    /**
     * Sets the text to wrap, preserving any embedded word styles.
     */
    public @NonNull WrappedLabelWidget setValue(@NonNull String value)
    {
        this.value = value;
        return self();
    }

    /**
     * Selects double spacing after full stops without consulting document preferences.
     */
    public @NonNull WrappedLabelWidget setFullStopSpaces(boolean fullStopSpaces)
    {
        this.fullStopSpaces = fullStopSpaces;
        return self();
    }

    /* Build the ordinary paragraph shared by height calculation and drawing. */
    private @NonNull Paragraph paragraph()
    {
        return Paragraph
                .builder(getScreen(), wordRenderer, eventBus)
                .setDocumentStyle(STYLE)
                .setText(value)
                .build();
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
