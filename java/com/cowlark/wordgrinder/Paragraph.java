/* © 2023 David Given.
 * WordGrinder is licensed under the MIT open source license. See the COPYING
 * file in this distribution for the full text.
 */

package com.cowlark.wordgrinder;

import com.cowlark.wordgrinder.document.DocumentStyle;
import com.google.common.collect.ImmutableList;
import org.jspecify.annotations.NonNull;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;

/**
 * An immutable sequence of styled words, translated from paragraph.lua.
 * Word and line indices are zero-based. Wrapping, rendering, and position queries
 * which depend on wrapping are deferred until the layout implementation exists.
 */
public final class Paragraph implements Iterable<@NonNull String>
{
    /* Paragraph content and style remain fixed after construction. */
    public final @NonNull ImmutableList<@NonNull String> words;
    public final @NonNull DocumentStyle style;
    public final int number = 0;

    /**
     * Creates a paragraph from individual styled words; no words creates an empty paragraph.
     * The paragraph owns an immutable copy of the words.
     */
    public Paragraph(
            @NonNull DocumentStyle style,
            @NonNull String... words)
    {
        /* Accept individual words, including an empty paragraph. */
        this(style, ImmutableList.copyOf(words));
    }

    /**
     * Creates a paragraph with the supplied document style, copying the word list.
     * Subsequent edits to the caller's list do not affect the paragraph.
     */
    public Paragraph(
            @NonNull DocumentStyle style,
            @NonNull ImmutableList<@NonNull String> words)
    {
        this.style = style;
        this.words = words;
    }

    /**
     * Iterates over the words in order. The iterator does not support removal.
     */
    @Override
    public @NonNull Iterator<@NonNull String> iterator()
    {
        /* Match Lua's iteration over words without including paragraph metadata. */
        return words.iterator();
    }

    /**
     * Creates a paragraph with the same style and immutable words.
     * As in Lua, the document-assigned paragraph number is not copied.
     */
    public @NonNull Paragraph copy()
    {
        /* Copy words and style without the assigned paragraph number. */
        return new Paragraph(style, words);
    }

    /**
     * Returns the indentation in character cells for a zero-based line index.
     * Uses this paragraph's style: its first-line override for line zero, then its
     * ordinary indent, then zero.
     *
     * @throws IndexOutOfBoundsException if the line index is negative
     */
    public int getIndentOfLine(int line)
    {
        /* Reject indices which cannot identify a paragraph line. */
        if (line < 0)
            throw new IndexOutOfBoundsException("Negative line index: " + line);

        /* An explicit first-line indent of zero overrides the ordinary indent too. */
        Integer indent = line == 0 ? style.firstIndent() : null;
        if (indent == null)
            indent = style.indent();
        return indent == null ? 0 : indent;
    }

    /**
     * Copies the words from the zero-based start index to the end into a mutable list.
     * A start equal to the word count returns an empty list.
     *
     * @throws IndexOutOfBoundsException if start is outside zero through the word count
     */
    public @NonNull ImmutableList<@NonNull String> sub(int start)
    {
        /* Without a count, copy all remaining words. */
        return sub(start, words.size() - start);
    }

    /**
     * Copies at most count words from the zero-based start index into a mutable list.
     * The count is clamped to the number of remaining words; edits to the returned
     * list do not affect the paragraph.
     *
     * @throws IndexOutOfBoundsException if start is outside zero through the word count,
     *                                   or count is negative
     */
    public @NonNull ImmutableList<@NonNull String> sub(int start, int count)
    {
        /* Clamp the requested count to the available words, as in Lua. */
        if (start < 0 || start > words.size() || count < 0)
            throw new IndexOutOfBoundsException("Invalid paragraph slice: " + start + ", " + count);
        int length = Math.min(count, words.size() - start);
        return words.subList(start, start + length);
    }

    /**
     * Returns the paragraph's unstyled text, joining words with a single space.
     * An empty paragraph produces an empty string.
     */
    @Override
    public @NonNull String toString()
    {
        /* Remove embedded word styles and separate words with a single space. */
        List<String> text = new ArrayList<>(words.size());
        for (String word : words)
            text.add(Word.getWordText(word));
        return String.join(" ", text);
    }
}
