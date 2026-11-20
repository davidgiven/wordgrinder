package com.cowlark.wordgrinder.document;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertThrows;

import com.cowlark.wordgrinder.nativeinterface.Display;
import org.jspecify.annotations.NonNull;
import org.junit.Test;
import java.util.ArrayList;
import java.util.List;

public final class WordTest
{
    private static final String BOLD = Word.createStyleByte(Word.BOLD);
    private static final String NORMAL = Word.createStyleByte(0);
    private static final String UNDERLINE = Word.createStyleByte(Word.UNDERLINE);

    @Test
    public void parseWordReportsTextRunsWithDefaultStyles()
    {
        assertEquals(
                List.of(
                        new Word.StyledRun(Word.BRIGHT, "a😀"),
                        new Word.StyledRun(Word.BRIGHT | Word.BOLD, "é"),
                        new Word.StyledRun(Word.BRIGHT, "界")),
                Word.parseWord("a😀" + BOLD + "é" + NORMAL + "界", Word.BRIGHT));
    }

    @Test
    public void parsingSkipsEmptyRunsAndTrailingControls()
    {
        assertEquals(List.of(), Word.parseWord("", 0));
        assertEquals(List.of(), Word.parseWord(BOLD + NORMAL, 0));
        assertEquals(
                List.of(new Word.StyledRun(Word.UNDERLINE, "x")),
                Word.parseWord(BOLD + UNDERLINE + "x" + NORMAL, 0));
        List<String> calls = new ArrayList<>();
        Word.parseWord(BOLD + "hello", 0, (style, text) -> calls.add(style + ":" + text));
        assertEquals(List.of(Word.BOLD + ":hello"), calls);
    }

    @Test
    public void getWordTextRemovesStylesWithoutLosingUnicodeOrEndingAtNul()
    {
        assertEquals("é😀界a\u0301", Word.getWordText(BOLD + "é😀\0界a\u0301" + NORMAL));
        assertEquals("ab", Word.getWordText("a\u0085b"));
        assertEquals("", Word.getWordText(BOLD));
    }

    @Test
    public void nextCharacterUsesUtf16OffsetsAndSkipsStylePrefixes()
    {
        String word = BOLD + "😀é" + NORMAL;
        assertEquals(3, Word.nextCharInWord(word, 0));
        assertEquals(3, Word.nextCharInWord(word, 1));
        assertEquals(4, Word.nextCharInWord(word, 3));
        assertEquals(-1, Word.nextCharInWord(word, 4));
        assertEquals(-1, Word.nextCharInWord(word, word.length()));
        assertEquals(-1, Word.nextCharInWord("", 0));
    }

    @Test
    public void previousCharacterIncludesStylePrefixAndSkipsTrailingControls()
    {
        String word = "a" + BOLD + "😀" + NORMAL;
        assertEquals(1, Word.prevCharInWord(word, word.length()));
        assertEquals(1, Word.prevCharInWord(word, 4));
        assertEquals(0, Word.prevCharInWord(word, 1));
        assertEquals(-1, Word.prevCharInWord(word, 0));
        assertEquals(-1, Word.prevCharInWord(BOLD + NORMAL, 2));
    }

    @Test
    public void navigationTreatsCombiningCharactersAsSeparateCodePoints()
    {
        assertEquals(1, Word.nextCharInWord("a\u0301", 0));
        assertEquals(2, Word.nextCharInWord("a\u0301", 1));
        assertEquals(1, Word.prevCharInWord("a\u0301", 2));
    }

    @Test
    public void getStyleUsesControlsStrictlyBeforeOffset()
    {
        assertEquals(0, Word.getStyleFromWord("foo", 0));
        assertEquals(Word.ITALIC, Word.getStyleFromWord("\u0011foo", 1));
        assertEquals(0, Word.getStyleFromWord("\u0011f" + NORMAL + "oo", 3));
        assertEquals(0, Word.getStyleFromWord("f\u0011oo", 1));
        assertEquals(Word.ITALIC, Word.getStyleFromWord("f\u0011oo", 2));
        assertEquals(Word.BOLD, Word.getStyleFromWord("😀" + BOLD, 3));
    }

    @Test
    public void insertionPreservesSurroundingStylesAndReportsInsertedRange()
    {
        Word.InsertResult result = Word.insertIntoWord("ab", "😀", 1, Word.BOLD);
        assertEquals("a" + BOLD + "😀" + NORMAL + "b", result.word());
        assertEquals(1, result.startOffset());
        assertEquals(4, result.endOffset());
        assertEquals(BOLD + "😀", result.word().substring(result.startOffset(),
                result.endOffset()));
    }

    @Test
    public void insertionHonoursExplicitStylesAndSupportsEmptyWordsAndEndOffsets()
    {
        assertEquals(
                BOLD + "x" + NORMAL + "y",
                Word.insertIntoWord("", BOLD + "x" + NORMAL + "y", 0, Word.UNDERLINE).word());
        assertEquals("😀x", Word.insertIntoWord("😀", "x", 2, 0).word());
        Word.InsertResult empty = Word.insertIntoWord("ab", "", 1, 0);
        assertEquals("ab", empty.word());
        assertEquals(1, empty.startOffset());
        assertEquals(1, empty.endOffset());
    }

    @Test
    public void deletionUsesHalfOpenUtf16Ranges()
    {
        assertEquals("ad", Word.deleteFromWord("abcd", 1, 3));
        assertEquals("cd", Word.deleteFromWord("abcd", 0, 2));
        assertEquals("ab", Word.deleteFromWord("a😀b", 1, 3));
        assertEquals("", Word.deleteFromWord("😀", 0, 2));
        assertEquals("abc", Word.deleteFromWord("abc", 1, 1));
    }

    @Test
    public void deletionRetainsRemainingStylesAndDropsUnusedChanges()
    {
        assertEquals("b", Word.deleteFromWord(BOLD + "a" + NORMAL + "b", 1, 2));
        assertEquals(BOLD + "a", Word.deleteFromWord(BOLD + "a" + NORMAL + "b", 2, 4));
        assertEquals("ab", Word.deleteFromWord("a" + BOLD + "😀" + NORMAL + "b", 2, 4));
        assertEquals("", Word.deleteFromWord(BOLD + "😀" + NORMAL, 0, 4));
    }

    @Test
    public void applyStyleTracksCursorAfterInsertedMarkers()
    {
        Word.StyleResult result = Word.applyStyleToWord("a😀b", Word.BOLD, Word.STYLE_ALL, 1, 3, 1);
        assertEquals("a" + BOLD + "😀" + NORMAL + "b", result.word());
        assertEquals(2, result.cursorOffset());
        assertEquals(
                5,
                Word.applyStyleToWord("a😀b", Word.BOLD, Word.STYLE_ALL, 1, 3, 3).cursorOffset());
    }

    @Test
    public void applyStyleCanRemoveOneFlagAndKeepOthers()
    {
        String both = Word.createStyleByte(Word.BOLD | Word.UNDERLINE);
        Word.StyleResult result = Word.applyStyleToWord(both + "ab", 0, ~Word.BOLD, 0, 3, 3);
        assertEquals(UNDERLINE + "ab", result.word());
        assertEquals(3, result.cursorOffset());
        assertEquals(
                new Word.StyleResult("", 0),
                Word.applyStyleToWord("", Word.BOLD, -1, 0, 0, 0));
    }

    @Test
    public void editsNormalizeRedundantAndTrailingControls()
    {
        String messy = NORMAL + BOLD + BOLD + "😀" + NORMAL + BOLD;
        assertEquals(BOLD + "😀", Word.deleteFromWord(messy, 0, 0));
        assertEquals(BOLD + "😀", Word.insertIntoWord(messy, "", 0, 0).word());
        assertEquals(BOLD + "😀", Word.applyStyleToWord(messy, 0, -1, 0, 0, 0).word());
    }

    @Test
    public void styleCharactersEncodeOnlyTheFourEmbeddedFlags()
    {
        for (int style = 0; style <= Word.STYLE_ALL; style++)
            assertEquals(
                    String.valueOf((char) (style | Word.STYLE_MARKER)),
                    Word.createStyleByte(style));
        assertEquals(NORMAL, Word.createStyleByte(Word.BRIGHT | Word.DIM));
    }

    @Test
    public void styledDrawingUsesCodePointsAndRendererWidths()
    {
        RecordingRenderer renderer = new RecordingRenderer();
        assertEquals(0, Word.writeStyled(5, 2, "a😀b", 0, 1, 3, 0, renderer));
        assertEquals(
                List.of(
                        new Glyph(5, 2, 'a', 0),
                        new Glyph(6, 2, 0x1f600, Word.REVERSE),
                        new Glyph(8, 2, 'b', 0)), renderer.glyphs);
        assertEquals(0, renderer.attributes);
    }

    @Test
    public void styledDrawingBridgesMatchingUnderlinedWordsAndKeepsFinalStyle()
    {
        RecordingRenderer renderer = new RecordingRenderer();
        assertEquals(
                Word.UNDERLINE,
                Word.writeStyled(3, 0, UNDERLINE + "x", Word.UNDERLINE, -1, -1, 0, renderer));
        assertEquals(
                List.of(new Glyph(2, 0, 160, Word.UNDERLINE), new Glyph(3, 0, 'x', Word.UNDERLINE)),
                renderer.glyphs);
        assertEquals(Word.REVERSE, Word.writeStyled(0, 0, "x", 0, 0, 1, 0, renderer));
        assertEquals(0, renderer.attributes);
    }

    @Test
    public void offsetsCannotSplitSurrogatePairsOrLeaveTheString()
    {
        assertThrows(IllegalArgumentException.class, () -> Word.nextCharInWord("😀", 1));
        assertThrows(IllegalArgumentException.class, () -> Word.prevCharInWord("😀", 1));
        assertThrows(IllegalArgumentException.class, () -> Word.insertIntoWord("😀", "x", 1, 0));
        assertThrows(IllegalArgumentException.class, () -> Word.deleteFromWord("😀", 0, 1));
        assertThrows(
                IllegalArgumentException.class,
                () -> Word.applyStyleToWord("😀", 0, -1, 0, 2, 1));
        assertThrows(IndexOutOfBoundsException.class, () -> Word.getStyleFromWord("a", 2));
        assertThrows(IllegalArgumentException.class, () -> Word.deleteFromWord("a", 1, 0));
    }

    /* The constructor must route default rendering to the supplied display only. */
    @Test
    public void styledDrawingUsesInjectedDisplay()
    {
        RecordingRenderer renderer = new RecordingRenderer();
        Display display = new Display()
        {
            @Override
            public void dpy_init(@NonNull String @NonNull [] args)
            {
                throw new AssertionError("Unexpected display call");
            }

            @Override
            public int @NonNull [] dpy_getscreensize()
            {
                throw new AssertionError("Unexpected display call");
            }

            @Override
            public @NonNull String dpy_getkeyname(int key)
            {
                throw new AssertionError("Unexpected display call");
            }

            @Override
            public void dpy_setcolour(
                    float foregroundRed,
                    float foregroundGreen,
                    float foregroundBlue,
                    float backgroundRed,
                    float backgroundGreen,
                    float backgroundBlue)
            {
                throw new AssertionError("Unexpected display call");
            }

            @Override
            public void dpy_start()
            {
                throw new AssertionError("Unexpected display call");
            }

            @Override
            public void dpy_shutdown()
            {
                throw new AssertionError("Unexpected display call");
            }

            @Override
            public void dpy_setattr(int andmask, int ormask)
            {
                assertEquals(0, andmask);
                renderer.setAttributes(ormask);
            }

            @Override
            public void dpy_writechar(int x, int y, int c)
            {
                renderer.writeCodePoint(x, y, c);
            }

            @Override
            public void dpy_setcursor(int x, int y, boolean shown)
            {
                throw new AssertionError("Unexpected display call");
            }

            @Override
            public void dpy_clearscreen()
            {
                throw new AssertionError("Unexpected display call");
            }

            @Override
            public void dpy_sync()
            {
                throw new AssertionError("Unexpected display call");
            }

            @Override
            public void dpy_cleararea(int x1, int y1, int x2, int y2)
            {
                throw new AssertionError("Unexpected display call");
            }

            @Override
            public int getCharacterWidth(int codePoint)
            {
                return renderer.width(codePoint);
            }

            @Override
            public int dpy_getchar(double timeout)
            {
                throw new AssertionError("Unexpected display call");
            }
        };
        Word word = new Word(display);
        assertEquals(Word.BOLD, word.writeStyled(5, 2, BOLD + "😀a", 0, -1, -1, 0));
        assertEquals(
                List.of(new Glyph(5, 2, 0x1f600, Word.BOLD), new Glyph(7, 2, 'a', Word.BOLD)),
                renderer.glyphs);
        assertEquals(0, renderer.attributes);
    }

    private record Glyph(int x, int y, int codePoint, int style)
    {
    }

    private static final class RecordingRenderer implements Word.Renderer
    {
        final List<Glyph> glyphs = new ArrayList<>();
        int attributes;

        @Override
        public void setAttributes(int attributes)
        {
            this.attributes = attributes;
        }

        @Override
        public void writeCodePoint(int x, int y, int codePoint)
        {
            glyphs.add(new Glyph(x, y, codePoint, attributes));
        }

        @Override
        public int width(int codePoint)
        {
            if (codePoint == 0x301)
                return 0;
            return codePoint == 0x1f600 ? 2 : 1;
        }
    }
}
