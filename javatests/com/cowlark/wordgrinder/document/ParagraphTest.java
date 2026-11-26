package com.cowlark.wordgrinder.document;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotSame;
import static org.junit.Assert.assertSame;
import static org.junit.Assert.assertThrows;

import com.cowlark.wordgrinder.eventbus.EventBus;
import com.cowlark.wordgrinder.nativeinterface.Display;
import com.cowlark.wordgrinder.nativeinterface.Screen;
import com.google.common.collect.ImmutableList;
import org.jspecify.annotations.Nullable;
import com.cowlark.wordgrinder.utils.Injector;
import org.junit.Test;
import java.lang.reflect.Proxy;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;

public final class ParagraphTest
{
    /* Unnumbered list paragraphs continue numbering, while normal text resets it. */
    @Test
    public void renumbersDocumentListsAndCountsWords()
    {
        var builder = builder();
        var document = new Document();
        var numbered = new DocumentStyle("Numbered", "N", 0, 0, 0, null, true, null, true, null);
        var bulleted = new DocumentStyle("Bulleted", "B", 0, 0, 0, "*", true, null, false, null);
        var first = builder.setDocumentStyle(numbered).setWords("one", "two").build();
        var bullet = builder.setDocumentStyle(bulleted).setWords("three").build();
        var second = builder.setDocumentStyle(numbered).setWords("four").build();
        var plain = builder.setDocumentStyle(style(0, null)).setWords("five").build();
        var restarted = builder.setDocumentStyle(numbered).setWords("six").build();
        document.paragraphs = List.of(first, bullet, second, plain, restarted);

        /* Verify the visible list numbers and the total across all paragraphs. */
        document.renumber();
        assertEquals(1, first.number);
        assertEquals(0, bullet.number);
        assertEquals(2, second.number);
        assertEquals(0, plain.number);
        assertEquals(1, restarted.number);
        assertEquals(6, document.wordCount);
    }

    /* Supply deterministic terminal widths; wrapping must not invoke any drawing operations. */
    private static Screen screen()
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
    private static Word wordRenderer()
    {
        Display display = (Display) Proxy.newProxyInstance(
                Display.class.getClassLoader(),
                new Class<?>[]{Display.class},
                (proxy, method, args) -> {
                    throw new AssertionError("Unexpected display operation: " + method.getName());
                });
        return new Word(display);
    }

    /* Bind deterministic collaborators for each independent paragraph builder. */
    private static Paragraph.Builder builder()
    {
        Injector.resetForTesting();
        Injector.bindInstance(Screen.class, screen());
        Injector.bindInstance(Word.class, wordRenderer());
        Injector.bindInstance(EventBus.class, new EventBus());
        return Paragraph.builder();
    }

    private static DocumentStyle style(int indent, @Nullable Integer firstIndent)
    {
        /* Only indentation fields matter for these paragraph queries. */
        return new DocumentStyle(
                "Paragraph",
                "P",
                0,
                0,
                indent,
                null,
                false,
                firstIndent,
                false,
                null);
    }

    @Test
    public void buildersSnapshotWordsAndPreserveIterationOrder()
    {
        /* Copy the input while retaining the supplied style. */
        ImmutableList<String> input = ImmutableList.of("one", "two");
        Paragraph paragraph = builder()
                .setDocumentStyle(style(0, null))
                .setWords(input)
                .build();
        assertEquals("P", paragraph.style().name());
        assertEquals(List.of("one", "two"), paragraph.words());

        /* Iteration yields the immutable snapshot in order. */
        List<String> iterated = new ArrayList<>();
        for (String word : paragraph)
            iterated.add(word);
        assertEquals(List.of("one", "two"), iterated);
        assertEquals(
                paragraph.words(),
                builder()
                        .setDocumentStyle(style(0, null))
                        .setWords("one", "two")
                        .build().words());
    }

    @Test
    public void reusedBuildersKeepPreviouslyBuiltParagraphsImmutable()
    {
        /* Snapshot mutable input when setting words, including before the first build. */
        DocumentStyle originalStyle = style(4, 0);
        List<String> input = new ArrayList<>(List.of("original"));
        Paragraph.Builder builder = builder()
                .setDocumentStyle(originalStyle)
                .setWords(input);
        input.set(0, "changed");
        Paragraph original = builder.build();
        assertEquals(List.of("original"), original.words());

        /* Reconfiguring the builder must not alter a paragraph or its cached layout. */
        Paragraph.WrapData layout = original.wrap(20, false);
        DocumentStyle replacementStyle = style(1, 2);
        Paragraph replacement =
                builder.setDocumentStyle(replacementStyle).setWords("replacement").build();
        assertSame(originalStyle, original.style());
        assertSame(replacementStyle, replacement.style());
        assertEquals(List.of("original"), original.words());
        assertEquals(List.of("replacement"), replacement.words());
        assertSame(layout, original.wrap(20, false));
    }

    @Test
    public void builderRequiresAStyleAndDefaultsToEmptyWords()
    {
        /* Omitted required configuration fails before constructing an incomplete paragraph. */
        Paragraph.Builder builder = builder();
        assertThrows(IllegalStateException.class, builder::build);
        assertEquals(List.of(), builder.setDocumentStyle(style(0, null)).build().words());
    }

    @Test
    public void setTextMatchesLuaWhitespaceAndPreservesStyledWords()
    {
        /* Only the four Lua separators split words; Unicode and embedded styles survive. */
        Paragraph paragraph = builder()
                .setDocumentStyle(style(0, null))
                .setText(" \t\u0018Héllo\n😀\r\nworld\u00a0joined\tform\ffeed  ")
                .build();
        assertEquals(
                List.of("\u0018Héllo", "😀", "world\u00a0joined", "form\ffeed"),
                paragraph.words());
    }

    @Test
    public void setTextReplacesWordsWithoutChangingPreviouslyBuiltParagraphs()
    {
        /* Text and word setters replace the same snapshot, with the last setter taking effect. */
        Paragraph.Builder builder = builder()
                .setDocumentStyle(style(0, null))
                .setWords("original");
        Paragraph original = builder.build();
        assertEquals(List.of("one", "two"), builder.setText("one two").build().words());
        assertEquals(List.of("explicit"), builder.setWords("explicit").build().words());
        assertEquals(List.of("original"), original.words());

        /* Unlike an omitted word list, empty text deliberately contains one empty word. */
        assertEquals(List.of(""), builder.setText("").build().words());
        assertEquals(List.of(""), builder.setText(" \t\r\n").build().words());
    }

    @Test
    public void copyingPreservesWordsAndStyleButNotParagraphNumber()
    {
        /* Copying retains the immutable content and style. */
        Paragraph original = builder()
                .setDocumentStyle(style(4, 7))
                .setWords("first", "second")
                .build();
        Paragraph copy = original.copy();
        assertSame(original.style(), copy.style());
        assertEquals(original.words(), copy.words());
        assertEquals(0, copy.number);

        /* Both instances reject edits to their word lists. */
        assertThrows(UnsupportedOperationException.class, () -> copy.words().set(0, "changed"));
        assertThrows(UnsupportedOperationException.class, () -> original.words().add("changed"));
        assertEquals("first", original.words().get(0));
        assertEquals(4, original.style().indent());
    }

    @Test
    public void arraysAndIteratorsCannotMutateParagraphWords()
    {
        /* Mutating the varargs array must not change the snapshot. */
        String[] input = {"first", "second"};
        Paragraph paragraph = builder()
                .setDocumentStyle(style(0, null))
                .setWords(input)
                .build();
        input[0] = "changed";
        assertEquals(List.of("first", "second"), paragraph.words());

        /* Public list access, sublists, and iteration must all reject mutation. */
        assertThrows(UnsupportedOperationException.class, () -> paragraph.words().clear());
        assertThrows(
                UnsupportedOperationException.class,
                () -> paragraph.words().subList(0, 1).clear());
        var iterator = paragraph.iterator();
        iterator.next();
        assertThrows(UnsupportedOperationException.class, iterator::remove);
    }

    @Test
    public void invalidSlicesAndLineIndicesAreRejected()
    {
        /* Fail on invalid indices rather than silently truncating at the start. */
        Paragraph paragraph = builder()
                .setDocumentStyle(style(0, null))
                .setWords("word")
                .build();
        assertThrows(IndexOutOfBoundsException.class, () -> paragraph.sub(-1));
        assertThrows(IndexOutOfBoundsException.class, () -> paragraph.sub(2));
        assertThrows(IndexOutOfBoundsException.class, () -> paragraph.sub(0, -1));
        assertThrows(IndexOutOfBoundsException.class, () -> paragraph.getIndentOfLine(-1));
    }

    @Test
    public void textStripsEmbeddedStylesAndPreservesUnicode()
    {
        /* Joining words preserves Unicode and removes only the word control codes. */
        Paragraph paragraph = builder()
                .setDocumentStyle(style(0, null))
                .setWords("\u0018Héllo", "😀\u0010world")
                .build();
        assertEquals("Héllo 😀world", paragraph.toString());
        assertEquals(
                "",
                builder()
                        .setDocumentStyle(style(0, null))
                        .build()
                        .toString());
    }

    @Test
    public void indentationUsesFirstLineOverrideThenOrdinaryIndentThenZero()
    {
        /* A zero first-line override is present, rather than a missing value. */
        DocumentStyle style = style(4, 0);
        Paragraph paragraph = builder()
                .setDocumentStyle(style)
                .build();
        assertSame(style, paragraph.style());
        assertEquals(0, paragraph.getIndentOfLine(0));
        assertEquals(4, paragraph.getIndentOfLine(1));
        assertEquals(
                7,
                builder()
                        .setDocumentStyle(style(4, 7))
                        .build()
                        .getIndentOfLine(0));

        /* Missing indentation values fall back in the same order as Lua. */
        assertEquals(
                4,
                builder()
                        .setDocumentStyle(style(4, null))
                        .build()
                        .getIndentOfLine(0));
        assertEquals(
                0,
                builder()
                        .setDocumentStyle(style(0, null))
                        .build()
                        .getIndentOfLine(0));
        assertEquals(
                0,
                builder()
                        .setDocumentStyle(style(0, 7))
                        .build()
                        .getIndentOfLine(2));
    }

    /* Preserve all three wrapping fixtures from tests/line-wrapping.lua with zero-based indices. */
    @Test
    public void wrapsLikeTheLuaRegressionFixtures()
    {
        String[] words = "The quick brown fox jumps over the lazy dog.".split(" ");
        Paragraph.WrapData ordinary = builder()
                .setDocumentStyle(style(0, null))
                .setWords(words)
                .build()
                .wrap(20, false);
        assertEquals(
                List.of(List.of(0, 1, 2), List.of(3, 4, 5, 6), List.of(7, 8)),
                ordinary.lines().stream().map(Paragraph.Line::words).toList());
        assertEquals(List.of(0, 4, 10, 0, 4, 10, 15, 0, 5), ordinary.xs());
        assertEquals(
                List.of(0, 3, 7),
                ordinary.lines().stream().map(Paragraph.Line::firstWord).toList());

        /* Ordinary indentation affects every line, while the first-line override affects only
        one. */
        Paragraph.WrapData indented = builder()
                .setDocumentStyle(style(4, null))
                .setWords(words)
                .build()
                .wrap(20, false);
        assertEquals(
                List.of(List.of(0, 1), List.of(2, 3), List.of(4, 5, 6), List.of(7, 8)),
                indented.lines().stream().map(Paragraph.Line::words).toList());
        assertEquals(List.of(0, 4, 0, 6, 0, 6, 11, 0, 5), indented.xs());
        Paragraph.WrapData firstIndent = builder()
                .setDocumentStyle(style(0, 15))
                .setWords(words)
                .build()
                .wrap(20, false);
        assertEquals(
                List.of(List.of(0), List.of(1, 2, 3), List.of(4, 5, 6), List.of(7, 8)),
                firstIndent.lines().stream().map(Paragraph.Line::words).toList());
        assertEquals(List.of(0, 0, 6, 12, 0, 6, 11, 0, 5), firstIndent.xs());
    }

    /* Sentence spacing participates in the cache and can change both positions and line breaks. */
    @Test
    public void cachesBothWidthAndFullStopSpacing()
    {
        Paragraph paragraph = builder()
                .setDocumentStyle(style(0, null))
                .setWords("Hi.", "there", "friend")
                .build();
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
        Paragraph paragraph = builder()
                .setDocumentStyle(style(0, null))
                .setWords("abc")
                .build();
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
        Paragraph paragraph = builder()
                .setDocumentStyle(style(0, null))
                .setWords("\u0018界", "e\u0301", "😀")
                .build();
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
        Paragraph paragraph = builder()
                .setDocumentStyle(style(0, null))
                .setWords("Hello", "world", "Stop.", "Next", "é", "tail", "")
                .build();
        assertEquals(Set.of(0, 3, 5, 6), paragraph.wrap(80, false).sentences());
        Paragraph styled = builder()
                .setDocumentStyle(style(0, null))
                .setWords("One.\u0010", "two", "three")
                .build();
        assertEquals(Set.of(0, 1, 2), styled.wrap(80, true).sentences());
        assertEquals(List.of(0, 5, 9), styled.wrap(80, true).xs());
    }

    /* Empty content and an explicit empty word remain distinct, and layouts stay immutable. */
    @Test
    public void handlesEmptyParagraphsAndKeepsLayoutsImmutable()
    {
        Paragraph.WrapData empty = builder()
                .setDocumentStyle(style(0, null))
                .build()
                .wrap(20, false);
        assertEquals(List.of(), empty.lines());
        assertEquals(List.of(), empty.xs());
        assertEquals(Set.of(), empty.sentences());
        Paragraph paragraph = builder()
                .setDocumentStyle(style(0, null))
                .setWords("")
                .build();
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
