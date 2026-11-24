package com.cowlark.wordgrinder.document;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertSame;
import static org.junit.Assert.assertThrows;
import static org.junit.Assert.fail;

import com.cowlark.wordgrinder.eventbus.DrawWordEvent;
import com.cowlark.wordgrinder.eventbus.EventBus;
import com.cowlark.wordgrinder.nativeinterface.Display;
import com.cowlark.wordgrinder.nativeinterface.Screen;
import org.junit.Test;
import java.lang.reflect.Proxy;
import java.util.ArrayList;
import java.util.List;

/**
 * Verifies paragraph line rendering and mutable DrawWord events without native code.
 */
public class ParagraphRenderTest
{
    /* Wrapped positions and Unicode cell widths control drawing of the requested line only. */
    @Test
    public void rendersOneLineAtItsWrappedPositions()
    {
        Drawing drawing = new Drawing();
        Paragraph paragraph = drawing.paragraph("P", "界", "a", "😀");
        Paragraph.WrapData layout = paragraph.wrap(6, false);
        paragraph.renderLine(layout.lines().get(0), 5, 7, false);
        assertEquals(List.of(new Glyph(5, 7, '界', 0), new Glyph(8, 7, 'a', 0)), drawing.glyphs);
        drawing.glyphs.clear();
        paragraph.renderLine(layout.lines().get(1), 5, 8, false);
        assertEquals(List.of(new Glyph(5, 8, 0x1f600, 0)), drawing.glyphs);
        assertEquals(0, drawing.attributes);
    }

    /* Heading markup is applied afresh to every word, alongside embedded word styles. */
    @Test
    public void appliesLuaHeadingMarkup()
    {
        String[] styles = {"H1", "H2", "H3", "H4", "P", "unknown"};
        int[] expected = {Word.ITALIC | Word.BRIGHT | Word.BOLD | Word.UNDERLINE,
                Word.BRIGHT | Word.BOLD | Word.UNDERLINE,
                Word.ITALIC | Word.BRIGHT | Word.BOLD,
                Word.BRIGHT | Word.BOLD,
                0,
                0};
        for (int i = 0; i < styles.length; i++)
        {
            Drawing drawing = new Drawing();
            Paragraph paragraph =
                    drawing.paragraph(styles[i], Word.createStyleByte(Word.REVERSE) + "a");
            paragraph.renderLine(paragraph.wrap(80, false).lines().get(0), 0, 0, false);
            assertEquals(List.of(new Glyph(0, 0, 'a', expected[i] | Word.REVERSE)), drawing.glyphs);
            assertEquals(0, drawing.attributes);
        }
    }

    /* Event mutations affect rendering, but not the immutable words or precomputed positions. */
    @Test
    public void honoursDrawWordMutationsAndStyleCarry()
    {
        Drawing drawing = new Drawing();
        Paragraph paragraph = drawing.paragraph("P", "a", "b", "c");
        List<String> payloads = new ArrayList<>();
        drawing.events.addEventListener(
                DrawWordEvent.class, event -> {
                    payloads.add(
                            event.word + ":" + event.oldStyle + ":" + event.currentStyle + ":" +
                                    event.firstWord);
                    if (event.word.equals("a"))
                    {
                        event.word = "A";
                        event.currentStyle = Word.UNDERLINE;
                    } else if (event.word.equals("b"))
                    {
                        event.word = Word.createStyleByte(Word.UNDERLINE) + "B";
                        event.oldStyle = 0;
                    }
                });
        Paragraph.WrapData layout = paragraph.wrap(80, false);
        paragraph.renderLine(layout.lines().get(0), 10, 2, true);
        assertEquals(List.of("a:0:0:true", "b:2:0:false", "c:2:0:true"), payloads);
        assertEquals(
                List.of(
                        new Glyph(10, 2, 'A', Word.UNDERLINE),
                        new Glyph(12, 2, 'B', Word.UNDERLINE),
                        new Glyph(14, 2, 'c', 0)), drawing.glyphs);
        assertEquals(List.of("a", "b", "c"), paragraph.words);
        assertSame(layout, paragraph.wrap(80, false));
    }

    /* Suppressing DrawWord leaves all listener changes disabled without changing line placement. */
    @Test
    public void canSuppressDrawWordEvents()
    {
        Drawing drawing = new Drawing();
        drawing.events.addEventListener(DrawWordEvent.class, event -> fail("DrawWord is disabled"));
        Paragraph paragraph = drawing.paragraph("P", "a", "b");
        paragraph.renderLine(paragraph.wrap(80, false).lines().get(0), 3, 4, false);
        assertEquals(List.of(new Glyph(3, 4, 'a', 0), new Glyph(5, 4, 'b', 0)), drawing.glyphs);
    }

    /* Consecutive underlined words bridge their intervening space, but new lines reset carry. */
    @Test
    public void bridgesWordStylesButResetsAtEachLine()
    {
        Drawing drawing = new Drawing();
        String underlined = Word.createStyleByte(Word.UNDERLINE);
        Paragraph paragraph =
                drawing.paragraph("P", underlined + "a", underlined + "b", underlined + "c");
        Paragraph.WrapData layout = paragraph.wrap(6, false);
        paragraph.renderLine(layout.lines().get(0), 0, 0, false);
        paragraph.renderLine(layout.lines().get(1), 0, 1, false);
        assertEquals(
                List.of(
                        new Glyph(0, 0, 'a', Word.UNDERLINE),
                        new Glyph(1, 0, 160, Word.UNDERLINE),
                        new Glyph(2, 0, 'b', Word.UNDERLINE),
                        new Glyph(0, 1, 'c', Word.UNDERLINE)), drawing.glyphs);
    }

    /* Rendering needs layout first; an empty wrapped line emits no glyphs or events. */
    @Test
    public void requiresWrappingAndAcceptsEmptyLines()
    {
        Drawing drawing = new Drawing();
        Paragraph paragraph = drawing.paragraph("P", "long");
        Paragraph.Line empty = new Paragraph.Line(0, com.google.common.collect.ImmutableList.of());
        assertThrows(IllegalStateException.class, () -> paragraph.renderLine(empty, 0, 0, false));
        drawing.events.addEventListener(DrawWordEvent.class, event -> fail("The line is empty"));
        paragraph.renderLine(paragraph.wrap(2, false).lines().get(0), 0, 0, true);
        assertEquals(List.of(), drawing.glyphs);
    }

    /* Record glyphs with their final display attributes. */
    private record Glyph(int x, int y, int codePoint, int attributes)
    {
    }

    /* Adapt the existing renderer and screen interfaces to deterministic test metrics. */
    private static final class Drawing
    {
        final List<Glyph> glyphs = new ArrayList<>();
        final EventBus events = new EventBus();
        final Screen screen = (Screen) Proxy.newProxyInstance(
                Screen.class.getClassLoader(),
                new Class<?>[]{Screen.class},
                (proxy, method, args) -> {
                    if (!method.getName().equals("getStringWidth"))
                        throw new AssertionError(method.getName());
                    return ((String) args[0])
                            .codePoints()
                            .filter(cp -> !Character.isISOControl(cp))
                            .map(Drawing::width)
                            .sum();
                });
        final Display display = createDisplay();
        int attributes;

        /* Supplementary and East Asian characters occupy two cells in these fixtures. */
        private static int width(int cp)
        {
            return cp == 0x1f600 || cp == '界' ? 2 : cp == 0x301 ? 0 : 1;
        }

        /* Keep proxy callbacks outside field initialisers so member rearrangement is harmless. */
        private Display createDisplay()
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
                                return width((int) args[0]);
                            }
                            default -> throw new AssertionError(method.getName());
                        }
                        return null;
                    });
        }

        /* Give every paragraph the same renderer and shared listener registrations. */
        Paragraph paragraph(String style, String... words)
        {
            DocumentStyle documentStyle =
                    new DocumentStyle(style, style, 0, 0, null, null, null, null, null, null);
            return Paragraph
                    .builder(screen, new Word(display), events)
                    .setDocumentStyle(documentStyle)
                    .setWords(words)
                    .build();
        }
    }
}
