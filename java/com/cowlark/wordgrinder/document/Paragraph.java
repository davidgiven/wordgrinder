/* © 2023 David Given.
 * WordGrinder is licensed under the MIT open source license. See the COPYING
 * file in this distribution for the full text.
 */

package com.cowlark.wordgrinder.document;

import com.cowlark.wordgrinder.eventbus.DrawWordEvent;
import com.cowlark.wordgrinder.eventbus.EventBus;
import com.cowlark.wordgrinder.nativeinterface.Screen;
import com.cowlark.wordgrinder.utils.Injector;
import com.cowlark.wordgrinder.utils.Injector.Inject;
import com.google.common.collect.ImmutableList;
import com.google.common.collect.ImmutableSet;
import org.jspecify.annotations.Nullable;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;

/**
 * An immutable sequence of styled words, translated from paragraph.lua.
 * Word and line indices are zero-based. Layout uses terminal cell widths from the
 * injected screen. Line rendering uses the supplied word renderer and event bus.
 */
public final class Paragraph implements Iterable<String>
{
    /* Paragraph content and style remain fixed after construction. */
    private ImmutableList<String> words;
    private DocumentStyle style;

    /* Cache the list number assigned by the document. */
    public int number;

    /* Screen metrics remain fixed for this paragraph; only the most recent layout is cached. */
    private final Screen screen;

    /* Rendering uses the supplied word renderer and the application's shared event bus. */
    private final Word wordRenderer;
    private final EventBus eventBus;
    private @Nullable WrapData wrapData;

    /* Receive the collaborators shared by layout and rendering. */
    @Inject
    public Paragraph(Screen screen, Word wordRenderer, EventBus eventBus)
    {
        this.screen = screen;
        this.wordRenderer = wordRenderer;
        this.eventBus = eventBus;
    }

    /* Initialise the paragraph's immutable content before returning it to the caller. */
    private void setContent(DocumentStyle style, ImmutableList<String> words)
    {
        this.style = style;
        this.words = words;
    }

    /** Creates a builder backed by the application injector. */
    public static Builder builder()
    {
        return new Builder();
    }

    /** Returns the immutable words in document order. */
    public ImmutableList<String> words()
    {
        return words;
    }

    /** Returns the paragraph style. */
    public DocumentStyle style()
    {
        return style;
    }

    /**
     * Iterates over the words in order. The iterator does not support removal.
     */
    @Override
    public Iterator<String> iterator()
    {
        /* Match Lua's iteration over words without including paragraph metadata. */
        return words.iterator();
    }

    /**
     * Creates a paragraph with the same style and immutable words.
     * As in Lua, the document-assigned paragraph number is not copied.
     */
    public Paragraph copy()
    {
        return withWords(words);
    }

    /** Replaces the words while preserving paragraph style and rendering collaborators. */
    public Paragraph withWords(Iterable<String> replacement)
    {
        /* Rebuild the paragraph so its cached layout is recalculated for the new text. */
        Paragraph paragraph = new Paragraph(screen, wordRenderer, eventBus);
        paragraph.setContent(style, ImmutableList.copyOf(replacement));
        return paragraph;
    }

    /**
     * Returns the indentation in character cells for a zero-based line index.
     * Uses this paragraph's style: its first-line override for line zero, then its
     * ordinary indent.
     *
     * @throws IndexOutOfBoundsException if the line index is negative
     */
    public int getIndentOfLine(int line)
    {
        /* Reject indices which cannot identify a paragraph line. */
        if (line < 0)
            throw new IndexOutOfBoundsException("Negative line index: " + line);

        /* An explicit first-line indent of zero overrides the ordinary indent too. */
        Integer firstIndent = style.firstIndent();
        return line == 0 && firstIndent != null ? firstIndent : style.indent();
    }

    /**
     * Wraps styled words using explicit width and sentence-spacing preferences.
     * Word offsets are measured in terminal cells relative to the line's indentation.
     * As in Lua, a word and its trailing spacing move to the next line when they reach
     * or exceed the available width. An oversized first word leaves an empty first line.
     */
    public WrapData wrap(int width, boolean fullStopSpaces)
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
    public void renderLine(Line line, int x, int y, boolean fireDrawWord)
    {
        renderLine(line, x, y, fireDrawWord, 0, null, null);
    }

    /**
     * Draws a wrapped line with the selection from start (inclusive) to end (exclusive).
     * Supply the endpoints in document order. As in Lua, each word fires DrawWord.
     */
    public void renderMarkedLine(Line line, int x, int y, int paragraph, Position start, Position end)
    {
        renderLine(line, x, y, true, paragraph, start, end);
    }

    private void renderLine(Line line, int x, int y, boolean fireDrawWord, int paragraph,
            @Nullable Position start, @Nullable Position end)
    {
        /* Rendering requires the cached positions and sentence markers from wrapping. */
        WrapData layout = wrapData;
        if (layout == null)
            throw new IllegalStateException("Wrap the paragraph before rendering it");
        int currentStyle = style.cstyle();
        int oldStyle = 0;

        /* Use paragraph-relative word indices even when rendering a later wrapped line. */
        for (int wn : line.words())
        {
            /* Select the full word unless it contains one of the selection endpoints. */
            int reverseOn = -1;
            int reverseOff = -1;
            String word = words.get(wn);
            if (start != null && end != null
                    && new Position(paragraph, wn, word.length()).compareTo(start) >= 0
                    && new Position(paragraph, wn, 0).compareTo(end) <= 0)
            {
                reverseOn = paragraph == start.paragraph() && wn == start.word() ? start.offset() : 0;
                if (paragraph == end.paragraph() && wn == end.word())
                    reverseOff = end.offset();
            }

            /* Deliver the mutable payload synchronously before drawing at its wrapped position. */
            int wordStyle = currentStyle;
            if (fireDrawWord)
            {
                DrawWordEvent payload =
                        new DrawWordEvent(word, oldStyle, currentStyle, layout.sentences().contains(wn));
                eventBus.fireEvent(payload);
                if (!word.equals(payload.word))
                {
                    /* A replacement may no longer have a character at a marked offset. */
                    reverseOn = drawableBoundary(payload.word, reverseOn);
                    reverseOff = drawableBoundary(payload.word, reverseOff);
                }
                word = payload.word;
                oldStyle = payload.oldStyle;
                wordStyle = payload.currentStyle;
            }
            oldStyle = wordRenderer.writeStyled(
                    x + layout.xs().get(wn),
                    y,
                    word,
                    oldStyle,
                    reverseOn,
                    reverseOff,
                    wordStyle);
        }
    }

    private static int drawableBoundary(String word, int offset)
    {
        if (offset >= word.length()
                || (offset > 0 && Character.isSurrogatePair(word.charAt(offset - 1), word.charAt(offset))))
            return -1;
        return offset;
    }

    /**
     * Copies the words from the zero-based start index to the end into a mutable list.
     * A start equal to the word count returns an empty list.
     *
     * @throws IndexOutOfBoundsException if start is outside zero through the word count
     */
    public ImmutableList<String> sub(int start)
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
    public ImmutableList<String> sub(int start, int count)
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
    public String toString()
    {
        /* Remove embedded word styles and separate words with a single space. */
        List<String> text = new ArrayList<>(words.size());
        for (String word : words)
            text.add(Word.getWordText(word));
        return String.join(" ", text);
    }

    /**
     * Configures immutable paragraph content while retaining the injected collaborators.
     */
    public static final class Builder
    {
        /* Resolve collaborators from the injector; require a style before building. */
        private @Nullable DocumentStyle documentStyle;
        private ImmutableList<String> words = ImmutableList.of();

        private Builder()
        {
        }

        /**
         * Sets the paragraph's document style.
         */
        public Builder setDocumentStyle(DocumentStyle documentStyle)
        {
            this.documentStyle = documentStyle;
            return this;
        }

        /**
         * Captures an immutable snapshot of the supplied styled words.
         */
        public Builder setWords(Iterable<String> words)
        {
            this.words = ImmutableList.copyOf(words);
            return this;
        }

        /**
         * Captures individual styled words; no words creates an empty paragraph.
         */
        public Builder setWords(String... words)
        {
            this.words = ImmutableList.copyOf(words);
            return this;
        }

        /**
         * Splits text on spaces, tabs, CR and LF, matching Lua's ParseStringIntoWords.
         */
        public Builder setText(String text)
        {
            /* Preserve embedded styles and other characters within each word. */
            ImmutableList.Builder<String> words = ImmutableList.builder();
            int start = -1;
            for (int i = 0; i <= text.length(); i++)
            {
                char character = i < text.length() ? text.charAt(i) : ' ';
                boolean separator = character == ' ' || character == '\t' || character == '\r' ||
                        character == '\n';
                if (separator && start >= 0)
                {
                    words.add(text.substring(start, i));
                    start = -1;
                } else if (!separator && start < 0)
                    start = i;
            }

            /* Lua represents empty or whitespace-only text as a single empty word. */
            ImmutableList<String> content = words.build();
            return setWords(content.isEmpty() ? ImmutableList.of("") : content);
        }

        /**
         * Builds an independent paragraph; the builder can subsequently be reused.
         */
        public Paragraph build()
        {
            if (documentStyle == null)
                throw new IllegalStateException(
                        "Set the document style before building a " + "paragraph");
            /* Each build receives its own content and layout cache. */
            Paragraph paragraph = Injector.createFresh(Paragraph.class);
            paragraph.setContent(documentStyle, words);
            return paragraph;
        }
    }

    /**
     * A wrapped line's first paragraph word and its zero-based paragraph word indices.
     */
    public record Line(int firstWord, ImmutableList<Integer> words)
    {
    }

    /**
     * Cached layout data. Sentence markers identify the initial word, words following a raw
     * non-alphabetic ending, and the final word. Empty paragraphs have no markers or lines.
     */
    public record WrapData(int wrapWidth, boolean fullStopSpaces, ImmutableSet<Integer> sentences,
                           ImmutableList<Line> lines, ImmutableList<Integer> xs)
    {
        /** Returns the zero-based line containing a word, or -1 if it is absent. */
        public int lineOfWord(int word)
        {
            for (int line = 0; line < lines.size(); line++)
                if (lines.get(line).words().contains(word))
                    return line;
            return -1;
        }
    }
}
