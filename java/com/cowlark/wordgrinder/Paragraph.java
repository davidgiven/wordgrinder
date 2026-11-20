/* © 2023 David Given.
 * WordGrinder is licensed under the MIT open source license. See the COPYING
 * file in this distribution for the full text.
 */

package com.cowlark.wordgrinder;

import com.cowlark.wordgrinder.document.DocumentStyle;
import com.cowlark.wordgrinder.eventbus.DrawWord;
import com.cowlark.wordgrinder.eventbus.EventBus;
import com.cowlark.wordgrinder.nativeinterface.Screen;
import com.google.common.collect.ImmutableList;
import com.google.common.collect.ImmutableSet;
import org.jspecify.annotations.NonNull;
import org.jspecify.annotations.Nullable;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;

/**
 * An immutable sequence of styled words, translated from paragraph.lua.
 * Word and line indices are zero-based. Layout uses terminal cell widths from the
 * injected screen. Line rendering uses the supplied word renderer and event bus.
 */
public final class Paragraph implements Iterable<@NonNull String>
{
    /* Paragraph content and style remain fixed after construction. */
    public final @NonNull ImmutableList<@NonNull String> words;
    public final @NonNull DocumentStyle style;
    public final int number = 0;

    /* Screen metrics remain fixed for this paragraph; only the most recent layout is cached. */
    private final @NonNull Screen screen;

    /* Rendering uses the supplied word renderer and the application's shared event bus. */
    private final @NonNull Word wordRenderer;
    private final @NonNull EventBus eventBus;
    private @Nullable WrapData wrapData;

    /**
     * Creates a paragraph from individual styled words; no words creates an empty paragraph.
     * The paragraph owns an immutable copy of the words.
     */
    public Paragraph(
            @NonNull Screen screen,
            @NonNull Word wordRenderer,
            @NonNull EventBus eventBus,
            @NonNull DocumentStyle style,
            @NonNull String... words)
    {
        /* Accept individual words, including an empty paragraph. */
        this(screen, wordRenderer, eventBus, style, ImmutableList.copyOf(words));
    }

    /**
     * Creates a paragraph with the supplied document style, copying the word list.
     * Subsequent edits to the caller's list do not affect the paragraph.
     */
    public Paragraph(
            @NonNull Screen screen,
            @NonNull Word wordRenderer,
            @NonNull EventBus eventBus,
            @NonNull DocumentStyle style,
            @NonNull ImmutableList<@NonNull String> words)
    {
        this.screen = screen;
        this.wordRenderer = wordRenderer;
        this.eventBus = eventBus;
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
        return new Paragraph(screen, wordRenderer, eventBus, style, words);
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
     * Wraps styled words using explicit width and sentence-spacing preferences.
     * Word offsets are measured in terminal cells relative to the line's indentation.
     * As in Lua, a word and its trailing spacing move to the next line when they reach
     * or exceed the available width. An oversized first word leaves an empty first line.
     */
    public @NonNull WrapData wrap(int width, boolean fullStopSpaces)
    {
        /* Both layout inputs participate in the cache, since either can change line breaks. */
        if (wrapData != null && wrapData.wrapWidth() == width &&
                wrapData.fullStopSpaces() == fullStopSpaces)
            return wrapData;

        /* Match Lua's raw-word sentence heuristic, including its final-word marker. */
        ImmutableSet.Builder<Integer> sentences = ImmutableSet.builder();
        boolean sentence = true;
        for (int wn = 0; wn < words.size(); wn++)
        {
            String word = words.get(wn);
            if (sentence)
            {
                sentences.add(wn);
                sentence = false;
            }
            if (!word.isEmpty())
            {
                char last = word.charAt(word.length() - 1);
                if (!(last >= 'a' && last <= 'z') && !(last >= 'A' && last <= 'Z'))
                    sentence = true;
            }
        }
        if (!words.isEmpty())
            sentences.add(words.size() - 1);

        /* Account for first-line indentation before placing the words. */
        ImmutableList.Builder<Line> lines = ImmutableList.builder();
        ImmutableList.Builder<Integer> xs = ImmutableList.builder();
        ImmutableList.Builder<Integer> lineWords = ImmutableList.builder();
        int firstWord = 0;
        int availableWidth = width - getIndentOfLine(0);
        int x = 0;
        boolean firstLine = true;
        boolean lineHasWords = false;
        for (int wn = 0; wn < words.size(); wn++)
        {
            String word = words.get(wn);
            int wordWidth = screen.getStringWidth(word) + 1;
            if (fullStopSpaces && word.endsWith("."))
                wordWidth++;
            int wordX = x;
            x += wordWidth;

            /* A break changes the indentation only when leaving the first line. */
            if (x >= availableWidth)
            {
                lines.add(new Line(firstWord, lineWords.build()));
                if (firstLine)
                {
                    availableWidth += getIndentOfLine(0) - getIndentOfLine(1);
                    firstLine = false;
                }
                firstWord = wn;
                lineWords = ImmutableList.builder();
                x = wordWidth;
                wordX = 0;
            }
            xs.add(wordX);
            lineWords.add(wn);
            lineHasWords = true;
        }

        /* Publish an immutable layout so later wraps cannot mutate previously returned data. */
        if (lineHasWords)
            lines.add(new Line(firstWord, lineWords.build()));
        wrapData =
                new WrapData(width, fullStopSpaces, sentences.build(), lines.build(), xs.build());
        return wrapData;
    }

    /**
     * Draws one wrapped line, translating Lua's renderLine. Call wrap before rendering.
     * The origin already includes any desired indentation, as in the Lua caller.
     * When enabled, DrawWord listeners may change the rendered word and its styles;
     * cached word positions and the paragraph's immutable content remain unchanged.
     */
    public void renderLine(@NonNull Line line, int x, int y, boolean fireDrawWord)
    {
        /* Rendering requires the cached positions and sentence markers from wrapping. */
        WrapData layout = wrapData;
        if (layout == null)
            throw new IllegalStateException("Wrap the paragraph before rendering it");
        int currentStyle = style.cstyle();
        int oldStyle = 0;

        /* Deliver each mutable payload synchronously before drawing at its wrapped position. */
        for (int wn : line.words())
        {
            String word = words.get(wn);
            int wordStyle = currentStyle;
            if (fireDrawWord)
            {
                DrawWord payload = new DrawWord(word, oldStyle, currentStyle, layout.sentences().contains(wn));
                eventBus.fireEvent(payload);
                word = payload.word;
                oldStyle = payload.oldStyle;
                wordStyle = payload.currentStyle;
            }
            oldStyle = wordRenderer.writeStyled(
                    x + layout.xs().get(wn), y, word, oldStyle, -1, -1, wordStyle);
        }
    }

    /**
     * A wrapped line's first paragraph word and its zero-based paragraph word indices.
     */
    public record Line(int firstWord, @NonNull ImmutableList<@NonNull Integer> words)
    {
    }

    /**
     * Cached layout data. Sentence markers identify the initial word, words following a raw
     * non-alphabetic ending, and the final word. Empty paragraphs have no markers or lines.
     */
    public record WrapData(int wrapWidth, boolean fullStopSpaces,
                           @NonNull ImmutableSet<@NonNull Integer> sentences,
                           @NonNull ImmutableList<@NonNull Line> lines,
                           @NonNull ImmutableList<@NonNull Integer> xs)
    {
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
