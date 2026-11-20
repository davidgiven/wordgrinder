package com.cowlark.wordgrinder;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotSame;
import static org.junit.Assert.assertSame;
import static org.junit.Assert.assertThrows;

import com.cowlark.wordgrinder.document.DocumentStyle;
import com.cowlark.wordgrinder.eventbus.EventBus;
import com.cowlark.wordgrinder.nativeinterface.Display;
import com.cowlark.wordgrinder.nativeinterface.Screen;
import com.google.common.collect.ImmutableList;
import org.jspecify.annotations.NonNull;
import org.jspecify.annotations.Nullable;
import org.junit.Test;
import java.lang.reflect.Proxy;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;

public final class ParagraphTest
{
    /* Supply deterministic terminal widths; wrapping must not invoke any drawing operations. */
    private static @NonNull Screen screen()
    {
        return (Screen) Proxy.newProxyInstance(
                Screen.class.getClassLoader(),
                new Class<?>[]{Screen.class},
                (proxy, method, args) -> {
                    if (!method.getName().equals("getStringWidth"))
                        throw new AssertionError(
                                "Unexpected screen operation: " + method.getName());
                    int width = 0;
                    for (int cp : ((String) args[0]).codePoints().toArray())
                    {
                        if (!Character.isISOControl(cp) && cp != 0x0301)
                            width += cp == '界' || cp == 0x1f600 ? 2 : 1;
                    }
                    return width;
                });
    }

    /* Pure paragraph operations must not attempt to draw through their injected renderer. */
    private static @NonNull Word wordRenderer()
    {
        Display display = (Display) Proxy.newProxyInstance(
                Display.class.getClassLoader(), new Class<?>[] {Display.class},
                (proxy, method, args) ->
                {
                    throw new AssertionError("Unexpected display operation: " + method.getName());
                });
        return new Word(display);
    }

    private static @NonNull DocumentStyle style(
            @Nullable Integer indent,
            @Nullable Integer firstIndent)
    {
        /* Only indentation fields matter for these paragraph queries. */
        return new DocumentStyle(
                "Paragraph",
                "P",
                0,
                0,
                indent,
                null,
                null,
                firstIndent,
                null,
                null);
    }

    @Test
    public void constructorsSnapshotWordsAndPreserveIterationOrder()
    {
        /* Copy the input while retaining the supplied style. */
        ImmutableList<String> input = ImmutableList.of("one", "two");
        Paragraph paragraph = new Paragraph(screen(), wordRenderer(), new EventBus(), style(null, null), input);
        assertEquals("P", paragraph.style.name());
        assertEquals(List.of("one", "two"), paragraph.words);

        /* Iteration yields the immutable snapshot in order. */
        List<String> iterated = new ArrayList<>();
        for (String word : paragraph)
            iterated.add(word);
        assertEquals(List.of("one", "two"), iterated);
        assertEquals(
                paragraph.words,
                new Paragraph(screen(), wordRenderer(), new EventBus(), style(null, null), "one", "two").words);
    }

    @Test
    public void copyingPreservesWordsAndStyleButNotParagraphNumber()
    {
        /* Copying retains the immutable content and style. */
        Paragraph original = new Paragraph(screen(), wordRenderer(), new EventBus(), style(4, 7), "first", "second");
        Paragraph copy = original.copy();
        assertSame(original.style, copy.style);
        assertEquals(original.words, copy.words);
        assertEquals(0, copy.number);

        /* Both instances reject edits to their word lists. */
        assertThrows(UnsupportedOperationException.class, () -> copy.words.set(0, "changed"));
        assertThrows(UnsupportedOperationException.class, () -> original.words.add("changed"));
        assertEquals("first", original.words.get(0));
        assertEquals(4, original.style.indent().intValue());
    }

    @Test
    public void arraysAndIteratorsCannotMutateParagraphWords()
    {
        /* Mutating the varargs array must not change the snapshot. */
        String[] input = {"first", "second"};
        Paragraph paragraph = new Paragraph(screen(), wordRenderer(), new EventBus(), style(null, null), input);
        input[0] = "changed";
        assertEquals(List.of("first", "second"), paragraph.words);

        /* Public list access, sublists, and iteration must all reject mutation. */
        assertThrows(UnsupportedOperationException.class, () -> paragraph.words.clear());
        assertThrows(
                UnsupportedOperationException.class,
                () -> paragraph.words.subList(0, 1).clear());
        var iterator = paragraph.iterator();
        iterator.next();
        assertThrows(UnsupportedOperationException.class, iterator::remove);
    }

    @Test
    public void invalidSlicesAndLineIndicesAreRejected()
    {
        /* Fail on invalid indices rather than silently truncating at the start. */
        Paragraph paragraph = new Paragraph(screen(), wordRenderer(), new EventBus(), style(null, null), "word");
        assertThrows(IndexOutOfBoundsException.class, () -> paragraph.sub(-1));
        assertThrows(IndexOutOfBoundsException.class, () -> paragraph.sub(2));
        assertThrows(IndexOutOfBoundsException.class, () -> paragraph.sub(0, -1));
        assertThrows(IndexOutOfBoundsException.class, () -> paragraph.getIndentOfLine(-1));
    }

    @Test
    public void textStripsEmbeddedStylesAndPreservesUnicode()
    {
        /* Joining words preserves Unicode and removes only the word control codes. */
        Paragraph paragraph =
                new Paragraph(screen(), wordRenderer(), new EventBus(), style(null, null), "\u0018Héllo", "😀\u0010world");
        assertEquals("Héllo 😀world", paragraph.toString());
        assertEquals("", new Paragraph(screen(), wordRenderer(), new EventBus(), style(null, null)).toString());
    }

    @Test
    public void indentationUsesFirstLineOverrideThenOrdinaryIndentThenZero()
    {
        /* A zero first-line override is present, rather than a missing value. */
        DocumentStyle style = style(4, 0);
        Paragraph paragraph = new Paragraph(screen(), wordRenderer(), new EventBus(), style);
        assertSame(style, paragraph.style);
        assertEquals(0, paragraph.getIndentOfLine(0));
        assertEquals(4, paragraph.getIndentOfLine(1));
        assertEquals(7, new Paragraph(screen(), wordRenderer(), new EventBus(), style(4, 7)).getIndentOfLine(0));

        /* Missing indentation values fall back in the same order as Lua. */
        assertEquals(4, new Paragraph(screen(), wordRenderer(), new EventBus(), style(4, null)).getIndentOfLine(0));
        assertEquals(0, new Paragraph(screen(), wordRenderer(), new EventBus(), style(null, null)).getIndentOfLine(0));
        assertEquals(0, new Paragraph(screen(), wordRenderer(), new EventBus(), style(null, 7)).getIndentOfLine(2));
    }

    /* Preserve all three wrapping fixtures from tests/line-wrapping.lua with zero-based indices. */
    @Test
    public void wrapsLikeTheLuaRegressionFixtures()
    {
        String[] words = "The quick brown fox jumps over the lazy dog.".split(" ");
        Paragraph.WrapData ordinary =
                new Paragraph(screen(), wordRenderer(), new EventBus(), style(0, null), words).wrap(20, false);
        assertEquals(
                List.of(List.of(0, 1, 2), List.of(3, 4, 5, 6), List.of(7, 8)),
                ordinary.lines().stream().map(Paragraph.Line::words).toList());
        assertEquals(List.of(0, 4, 10, 0, 4, 10, 15, 0, 5), ordinary.xs());
        assertEquals(
                List.of(0, 3, 7),
                ordinary.lines().stream().map(Paragraph.Line::firstWord).toList());

        /* Ordinary indentation affects every line, while the first-line override affects only
        one. */
        Paragraph.WrapData indented =
                new Paragraph(screen(), wordRenderer(), new EventBus(), style(4, null), words).wrap(20, false);
        assertEquals(
                List.of(List.of(0, 1), List.of(2, 3), List.of(4, 5, 6), List.of(7, 8)),
                indented.lines().stream().map(Paragraph.Line::words).toList());
        assertEquals(List.of(0, 4, 0, 6, 0, 6, 11, 0, 5), indented.xs());
        Paragraph.WrapData firstIndent =
                new Paragraph(screen(), wordRenderer(), new EventBus(), style(0, 15), words).wrap(20, false);
        assertEquals(
                List.of(List.of(0), List.of(1, 2, 3), List.of(4, 5, 6), List.of(7, 8)),
                firstIndent.lines().stream().map(Paragraph.Line::words).toList());
        assertEquals(List.of(0, 0, 6, 12, 0, 6, 11, 0, 5), firstIndent.xs());
    }

    /* Sentence spacing participates in the cache and can change both positions and line breaks. */
    @Test
    public void cachesBothWidthAndFullStopSpacing()
    {
        Paragraph paragraph = new Paragraph(screen(), wordRenderer(), new EventBus(), style(null, null), "Hi.", "there", "friend");
        Paragraph.WrapData single = paragraph.wrap(11, false);
        assertSame(single, paragraph.wrap(11, false));
        assertEquals(List.of(0, 4, 0), single.xs());
        Paragraph.WrapData doubled = paragraph.wrap(11, true);
        assertNotSame(single, doubled);
        assertSame(doubled, paragraph.wrap(11, true));
        assertEquals(
                List.of(List.of(0), List.of(1), List.of(2)),
                doubled.lines().stream().map(Paragraph.Line::words).toList());
        assertEquals(11, doubled.wrapWidth());
        assertEquals(true, doubled.fullStopSpaces());
        assertEquals(List.of(0, 0, 0), doubled.xs());
        Paragraph.WrapData wider = paragraph.wrap(30, true);
        assertNotSame(doubled, wider);
        assertEquals(List.of(0, 5, 11), wider.xs());
        assertEquals(single, paragraph.wrap(11, false));
    }

    /* The Lua algorithm tests a word together with its trailing spacing, using >=. */
    @Test
    public void preservesExactFitAndOversizedFirstWordBehaviour()
    {
        Paragraph paragraph = new Paragraph(screen(), wordRenderer(), new EventBus(), style(null, null), "abc");
        Paragraph.WrapData exact = paragraph.wrap(4, false);
        assertEquals(
                List.of(List.of(), List.of(0)),
                exact.lines().stream().map(Paragraph.Line::words).toList());
        assertEquals(List.of(0, 0), exact.lines().stream().map(Paragraph.Line::firstWord).toList());
        assertEquals(exact.lines(), paragraph.wrap(2, false).lines());
        assertEquals(exact.lines(), paragraph.wrap(0, false).lines());
        assertEquals(
                List.of(List.of(0)),
                paragraph.wrap(5, false).lines().stream().map(Paragraph.Line::words).toList());
    }

    /* Screen metrics account for wide glyphs, combining marks and embedded style controls. */
    @Test
    public void wrapsUsingTerminalCellWidths()
    {
        Paragraph paragraph =
                new Paragraph(screen(), wordRenderer(), new EventBus(), style(null, null), "\u0018界", "e\u0301", "😀");
        Paragraph.WrapData wrapped = paragraph.wrap(6, false);
        assertEquals(
                List.of(List.of(0, 1), List.of(2)),
                wrapped.lines().stream().map(Paragraph.Line::words).toList());
        assertEquals(List.of(0, 3, 0), wrapped.xs());
    }

    /* Sentence markers use raw word endings, and always include the final word. */
    @Test
    public void retainsLuaSentenceMarkersAndRawFullStopDetection()
    {
        Paragraph paragraph = new Paragraph(
                screen(),
                wordRenderer(),
                new EventBus(),
                style(null, null),
                "Hello",
                "world",
                "Stop.",
                "Next",
                "é",
                "tail",
                "");
        assertEquals(Set.of(0, 3, 5, 6), paragraph.wrap(80, false).sentences());
        Paragraph styled = new Paragraph(screen(), wordRenderer(), new EventBus(), style(null, null), "One.\u0010", "two", "three");
        assertEquals(Set.of(0, 1, 2), styled.wrap(80, true).sentences());
        assertEquals(List.of(0, 5, 9), styled.wrap(80, true).xs());
    }

    /* Empty content and an explicit empty word remain distinct, and layouts stay immutable. */
    @Test
    public void handlesEmptyParagraphsAndKeepsLayoutsImmutable()
    {
        Paragraph.WrapData empty = new Paragraph(screen(), wordRenderer(), new EventBus(), style(null, null)).wrap(20, false);
        assertEquals(List.of(), empty.lines());
        assertEquals(List.of(), empty.xs());
        assertEquals(Set.of(), empty.sentences());
        Paragraph paragraph = new Paragraph(screen(), wordRenderer(), new EventBus(), style(null, null), "");
        Paragraph.WrapData oneWord = paragraph.wrap(20, false);
        assertEquals(
                List.of(List.of(0)),
                oneWord.lines().stream().map(Paragraph.Line::words).toList());
        assertEquals(Set.of(0), oneWord.sentences());
        assertThrows(UnsupportedOperationException.class, () -> oneWord.lines().clear());
        assertThrows(
                UnsupportedOperationException.class,
                () -> oneWord.lines().get(0).words()
                        .add(1));
        assertThrows(
                UnsupportedOperationException.class,
                () -> oneWord.sentences()
                        .add(1));
        assertThrows(UnsupportedOperationException.class, () -> oneWord.xs().set(0, 9));
        assertEquals(oneWord, paragraph.copy().wrap(20, false));
    }

}
