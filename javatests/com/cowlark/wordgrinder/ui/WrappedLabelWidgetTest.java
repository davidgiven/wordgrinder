package com.cowlark.wordgrinder.ui;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.fail;

import com.cowlark.wordgrinder.document.Word;
import com.cowlark.wordgrinder.eventbus.DrawWord;
import com.cowlark.wordgrinder.eventbus.EventBus;
import com.cowlark.wordgrinder.nativeinterface.Display;
import com.cowlark.wordgrinder.nativeinterface.Screen.KeyInputEvent;
import org.jspecify.annotations.NonNull;
import org.junit.Test;
import java.lang.reflect.Proxy;
import java.util.ArrayList;
import java.util.List;

/**
 * Exercises paragraph-based labels, including their integration with stretchy forms.
 */
public class WrappedLabelWidgetTest
{
    /* Split the same four whitespace characters as Lua and draw at the assigned origin. */
    @Test
    public void wrapsWhitespaceAndRendersEachLineWithoutEvents()
    {
        Drawing drawing = new Drawing();
        WrappedLabelWidget label =
                drawing.label(" \tThe quick\nbrown\rfox jumps over the lazy dog.  ", 20);
        label.realx1 = 5;
        label.realy1 = 7;
        assertFalse(label.focusable);
        assertEquals(3, label.calculateHeight());
        assertEquals(List.of(), drawing.glyphs);
        label.draw();
        assertEquals("The quick brown", drawing.row(7, 5));
        assertEquals("fox jumps over the", drawing.row(8, 5));
        assertEquals("lazy dog.", drawing.row(9, 5));
        assertEquals(0, drawing.attributes);
    }

    /* Empty or whitespace-only labels are represented by one empty paragraph word. */
    @Test
    public void emptyLabelsOccupyOneLine()
    {
        Drawing drawing = new Drawing();
        for (String text : List.of("", " \t\r\n"))
        {
            WrappedLabelWidget label = drawing.label(text, 20);
            assertEquals(1, label.calculateHeight());
            label.draw();
        }
        assertEquals(List.of(), drawing.glyphs);
    }

    /* Width and sentence-spacing changes must affect both measured and rendered layout. */
    @Test
    public void reflowsAfterWidthTextAndSpacingChanges()
    {
        Drawing drawing = new Drawing();
        WrappedLabelWidget label = drawing.label("Hi. there friend", 11);
        assertEquals(2, label.calculateHeight());
        label.setFullStopSpaces(true);
        assertEquals(3, label.calculateHeight());
        label.draw();
        assertEquals("Hi.", drawing.row(0, 0));
        assertEquals("there", drawing.row(1, 0));
        assertEquals("friend", drawing.row(2, 0));
        label.realwidth = 30;
        assertEquals(1, label.calculateHeight());
        label.setValue("replacement");
        drawing.glyphs.clear();
        label.draw();
        assertEquals("replacement", drawing.row(0, 0));
    }

    /* Paragraph rendering retains embedded styles and measures wide characters in cells. */
    @Test
    public void preservesStylesAndUnicodeCellWidths()
    {
        Drawing drawing = new Drawing();
        WrappedLabelWidget label = drawing.label(Word.createStyleByte(Word.BOLD) + "界 a 😀", 6);
        assertEquals(2, label.calculateHeight());
        label.draw();
        assertEquals(
                List.of(
                        new Glyph(0, 0, '界', Word.BOLD),
                        new Glyph(3, 0, 'a', 0),
                        new Glyph(0, 1, 0x1f600, 0)), drawing.glyphs);
    }

    /* Stretchy forms obtain their height from the same wrapping used for drawing. */
    @Test
    public void sizesStretchyFormsFromWrappedLabelHeight()
    {
        Drawing drawing = new Drawing();
        WrappedLabelWidget label = new WrappedLabelWidget(drawing.renderer, drawing.events)
                .setBounds(1, 1, -1, -1)
                .setValue("The quick brown fox jumps over the lazy dog.");
        drawing.screen.events.add(new KeyInputEvent("KEY_ESCAPE"));
        assertFalse(new Ui(drawing.screen).newForm().setSize(22, 2).setStretchy(true)
                .add(label).run());
        assertEquals(20, label.realwidth);
        assertEquals(3, label.realheight);
        assertEquals("The quick brown", drawing.row(10, 30));
        assertEquals("fox jumps over the", drawing.row(11, 30));
        assertEquals("lazy dog.", drawing.row(12, 30));
    }

    /* Record styled glyphs separately from the screen's form-frame writes. */
    private record Glyph(int x, int y, int codePoint, int attributes)
    {
    }

    private static class Drawing
    {
        final TestScreen screen = new TestScreen()
        {
            @Override
            public int getStringWidth(@NonNull String text)
            {
                return super.getStringWidth(Word.getWordText(text));
            }
        };
        final EventBus events = new EventBus();
        final List<Glyph> glyphs = new ArrayList<>();
        final Display display = createDisplay();
        final Word renderer = new Word(display);
        int attributes;

        /* No label operation may notify spellcheckers or any other word listeners. */
        Drawing()
        {
            events.addEventListener(DrawWord.class, event -> fail("Labels must suppress DrawWord"));
        }

        /* Keep proxy callbacks outside field initialisers so member rearrangement is harmless. */
        private @NonNull Display createDisplay()
        {
            return (Display) Proxy.newProxyInstance(
                    Display.class.getClassLoader(),
                    new Class<?>[]{Display.class},
                    (proxy, method, args) -> {
                        switch (method.getName())
                        {
                            case "dpy_setattr" ->
                                    attributes = (attributes & (int) args[0]) | (int) args[1];
                            case "dpy_writechar" -> glyphs.add(new Glyph(
                                    (int) args[0],
                                    (int) args[1],
                                    (int) args[2],
                                    attributes));
                            case "getCharacterWidth" ->
                            {
                                return screen.getStringWidth(new String(Character.toChars((int) args[0])));
                            }
                            default -> throw new AssertionError(method.getName());
                        }
                        return null;
                    });
        }

        /* Attach the screen as Form.add normally does, without needing to run an input loop. */
        WrappedLabelWidget label(@NonNull String text, int width)
        {
            WrappedLabelWidget label = new WrappedLabelWidget(renderer, events).setValue(text);
            new Ui(screen).newForm()
                    .add(label);
            label.realwidth = width;
            return label;
        }

        /* Recover visible text from glyph coordinates, including the unpainted spaces. */
        @NonNull String row(int y, int x)
        {
            StringBuilder text = new StringBuilder();
            int column = x;
            for (Glyph glyph : glyphs)
            {
                if (glyph.y() == y)
                {
                    while (column < glyph.x())
                    {
                        text.append(' ');
                        column++;
                    }
                    text.appendCodePoint(glyph.codePoint());
                    column = glyph.x() +
                            screen.getStringWidth(new String(Character.toChars(glyph.codePoint())));
                }
            }
            return text.toString();
        }
    }
}
