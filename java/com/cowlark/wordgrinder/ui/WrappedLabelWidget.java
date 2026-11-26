/* © 2026 David Given.
 * WordGrinder is licensed under the MIT open source licence. See COPYING.
 */

package com.cowlark.wordgrinder.ui;

import com.cowlark.wordgrinder.document.DocumentStyle;
import com.cowlark.wordgrinder.document.Paragraph;

/**
 * A label laid out and drawn as an ordinary paragraph, without DrawWord events.
 */
public class WrappedLabelWidget extends Widget<WrappedLabelWidget>
{
    /* Label paragraphs have no document indentation or heading attributes. */
    private static final DocumentStyle STYLE =
            new DocumentStyle("Paragraph", "P", 0, 0, 0, null, false, null, false, null);

    public String value = "";
    public boolean fullStopSpaces;

    /**
     * Sets the text to wrap, preserving any embedded word styles.
     */
    public WrappedLabelWidget setValue(String value)
    {
        this.value = value;
        return self();
    }

    /**
     * Selects double spacing after full stops without consulting document preferences.
     */
    public WrappedLabelWidget setFullStopSpaces(boolean fullStopSpaces)
    {
        this.fullStopSpaces = fullStopSpaces;
        return self();
    }

    /* Build the ordinary paragraph shared by height calculation and drawing. */
    private Paragraph paragraph()
    {
        return Paragraph
                .builder()
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
