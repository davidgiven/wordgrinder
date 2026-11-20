package com.cowlark.wordgrinder;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertSame;
import static org.junit.Assert.assertThrows;

import com.cowlark.wordgrinder.document.DocumentStyle;
import com.google.common.collect.ImmutableList;
import org.jspecify.annotations.NonNull;
import org.jspecify.annotations.Nullable;
import org.junit.Test;
import java.util.ArrayList;
import java.util.List;

public final class ParagraphTest
{
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
        Paragraph paragraph = new Paragraph(style(null, null), input);
        assertEquals("P", paragraph.style.name());
        assertEquals(List.of("one", "two"), paragraph.words);

        /* Iteration yields the immutable snapshot in order. */
        List<String> iterated = new ArrayList<>();
        for (String word : paragraph)
            iterated.add(word);
        assertEquals(List.of("one", "two"), iterated);
        assertEquals(paragraph.words, new Paragraph(style(null, null), "one", "two").words);
    }

    @Test
    public void copyingPreservesWordsAndStyleButNotParagraphNumber()
    {
        /* Copying retains the immutable content and style. */
        Paragraph original = new Paragraph(style(4, 7), "first", "second");
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
        Paragraph paragraph = new Paragraph(style(null, null), input);
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
        Paragraph paragraph = new Paragraph(style(null, null), "word");
        assertThrows(IndexOutOfBoundsException.class, () -> paragraph.sub(-1));
        assertThrows(IndexOutOfBoundsException.class, () -> paragraph.sub(2));
        assertThrows(IndexOutOfBoundsException.class, () -> paragraph.sub(0, -1));
        assertThrows(IndexOutOfBoundsException.class, () -> paragraph.getIndentOfLine(-1));
    }

    @Test
    public void textStripsEmbeddedStylesAndPreservesUnicode()
    {
        /* Joining words preserves Unicode and removes only the word control codes. */
        Paragraph paragraph = new Paragraph(style(null, null), "\u0018Héllo", "😀\u0010world");
        assertEquals("Héllo 😀world", paragraph.toString());
        assertEquals("", new Paragraph(style(null, null)).toString());
    }

    @Test
    public void indentationUsesFirstLineOverrideThenOrdinaryIndentThenZero()
    {
        /* A zero first-line override is present, rather than a missing value. */
        DocumentStyle style = style(4, 0);
        Paragraph paragraph = new Paragraph(style);
        assertSame(style, paragraph.style);
        assertEquals(0, paragraph.getIndentOfLine(0));
        assertEquals(4, paragraph.getIndentOfLine(1));
        assertEquals(7, new Paragraph(style(4, 7)).getIndentOfLine(0));

        /* Missing indentation values fall back in the same order as Lua. */
        assertEquals(4, new Paragraph(style(4, null)).getIndentOfLine(0));
        assertEquals(0, new Paragraph(style(null, null)).getIndentOfLine(0));
        assertEquals(0, new Paragraph(style(null, 7)).getIndentOfLine(2));
    }
}
