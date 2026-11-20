/* © 2008 David Given.
 * WordGrinder is licensed under the MIT open source license. See the COPYING
 * file in this distribution for the full text.
 */

package com.cowlark.wordgrinder.document;

import com.cowlark.wordgrinder.nativeinterface.Display;

import org.jspecify.annotations.NonNull;
import org.jspecify.annotations.Nullable;
import java.util.ArrayList;
import java.util.List;
import java.util.function.BiConsumer;

/**
 * Operations on strings containing embedded text styles, translated from src/c/word.cc.
 * Each word starts with all styles off. Control characters change the style to their
 * low four bits; emitted style markers have bit 4 set so they never contain NUL.
 *
 * <p>Offsets are zero-based UTF-16 indices, including style markers, and ranges are
 * end-exclusive. Offsets must not split a surrogate pair. Strings are length-delimited:
 * an embedded NUL is a control character, not a terminator. Navigation returns -1
 * when there is no next or previous character.
 */
public final class Word
{
    public static final int ITALIC = 1;
    public static final int UNDERLINE = 2;
    public static final int REVERSE = 4;
    public static final int BOLD = 8;
    public static final int BRIGHT = 16;
    public static final int DIM = 32;
    public static final int STYLE_MARKER = 16;
    public static final int STYLE_ALL = 15;

    /* Adapt the injected display to the styled-word renderer. */
    private final @NonNull Renderer renderer;

    public Word(@NonNull Display display)
    {
        renderer = new Renderer()
        {
            @Override
            public void setAttributes(int attributes)
            {
                display.dpy_setattr(0, attributes);
            }

            @Override
            public void writeCodePoint(int x, int y, int codePoint)
            {
                display.dpy_writechar(x, y, codePoint);
            }

            @Override
            public int width(int codePoint)
            {
                return display.getCharacterWidth(codePoint);
            }
        };
    }

    /**
     * Parses a word into nonempty text runs, combining each style with the default style.
     */
    public static @NonNull List<StyledRun> parseWord(@NonNull String word, int defaultStyle)
    {
        List<StyledRun> runs = new ArrayList<>();
        parseWord(word, defaultStyle, (style, text) -> runs.add(new StyledRun(style, text)));
        return runs;
    }

    /**
     * Calls the callback with the style and text of each nonempty run.
     */
    public static void parseWord(
            @NonNull String word,
            int defaultStyle,
            @NonNull BiConsumer<Integer, String> callback)
    {
        int start = 0;
        int style = 0;
        for (int i = 0; i < word.length(); )
        {
            int codePoint = word.codePointAt(i);
            int next = i + Character.charCount(codePoint);
            if (Character.isISOControl(codePoint))
            {
                if (start < i)
                    callback.accept(style | defaultStyle, word.substring(start, i));
                style = codePoint & STYLE_ALL;
                start = next;
            }
            i = next;
        }
        if (start < word.length())
            callback.accept(style | defaultStyle, word.substring(start));
    }

    /**
     * Draws a styled word through Java callbacks and returns its final attributes.
     * A -1 reverse offset disables that boundary. Selection boundaries are checked
     * before each code point, as in the original renderer. An end boundary at the end
     * of the string leaves REVERSE in the returned attributes for inter-word spacing.
     *
     * <p>If the first character continues reverse/underline from the previous word,
     * a non-breaking space is also drawn at x-1. Attributes are reset on return.
     */
    public static int writeStyled(
            int x,
            int y,
            @NonNull String word,
            int oldAttributes,
            int reverseOn,
            int reverseOff,
            int defaultStyle,
            @NonNull Renderer renderer)
    {
        if (reverseOn != -1)
            checkOffset(word, reverseOn);
        if (reverseOff != -1)
            checkOffset(word, reverseOff);
        int attributes = defaultStyle;
        int mark = 0;
        boolean first = true;
        renderer.setAttributes(attributes);
        try
        {
            for (int i = 0; i < word.length(); )
            {
                if (i == reverseOn)
                {
                    mark = REVERSE;
                    renderer.setAttributes(attributes | mark);
                }
                if (i == reverseOff)
                {
                    mark = 0;
                    renderer.setAttributes(attributes | mark);
                }
                int codePoint = word.codePointAt(i);
                i += Character.charCount(codePoint);
                if (Character.isISOControl(codePoint))
                {
                    attributes = (codePoint & STYLE_ALL) | defaultStyle;
                    renderer.setAttributes(attributes | mark);
                } else
                {
                    if (first && (oldAttributes & (REVERSE | UNDERLINE)) != 0 &&
                            (attributes | mark) == oldAttributes)
                        renderer.writeCodePoint(x - 1, y, 160);
                    renderer.writeCodePoint(x, y, codePoint);
                    x += renderer.width(codePoint);
                    first = false;
                }
            }
            return attributes | mark;
        } finally
        {
            renderer.setAttributes(0);
        }
    }

    /**
     * Returns the text of a word with its control/style characters removed.
     */
    public static @NonNull String getWordText(@NonNull String word)
    {
        StringBuilder result = new StringBuilder(word.length());
        for (int i = 0; i < word.length(); )
        {
            int codePoint = word.codePointAt(i);
            i += Character.charCount(codePoint);
            if (!Character.isISOControl(codePoint))
                result.appendCodePoint(codePoint);
        }
        return result.toString();
    }

    /**
     * Skips preceding style controls and one Unicode code point, or returns -1.
     */
    public static int nextCharInWord(@NonNull String word, int offset)
    {
        checkOffset(word, offset);
        while (offset < word.length() && isControlCode(word.charAt(offset)))
            offset++;
        return offset == word.length() ?
                -1 :
                offset + Character.charCount(word.codePointAt(offset));
    }

    /**
     * Backs up over one code point and its preceding style controls, or returns -1.
     */
    public static int prevCharInWord(@NonNull String word, int offset)
    {
        checkOffset(word, offset);
        int codePoint;
        do
        {
            if (offset == 0)
                return -1;
            codePoint = word.codePointBefore(offset);
            offset -= Character.charCount(codePoint);
        } while (isControlCode(codePoint));
        while (offset > 0 && isControlCode(word.charAt(offset - 1)))
            offset--;
        return offset;
    }

    /**
     * Inserts a styled word at an offset, normalizing redundant and trailing markers.
     * initialStyle applies until the inserted word's first explicit style change.
     * Returns the resulting string and the start/end offsets of the inserted section.
     */
    public static @NonNull InsertResult insertIntoWord(
            @NonNull String word,
            @NonNull String insertion,
            int offset,
            int initialStyle)
    {
        checkOffset(word, offset);
        Reader source = new Reader(word, 0);
        Writer result = new Writer();
        int start = -1;
        int end = -1;
        do
        {
            if (start == -1 && source.offset >= offset)
            {
                start = result.text.length();
                Reader inserted = new Reader(insertion, initialStyle);
                while (copy(result, inserted, 0, STYLE_ALL))
                {
                }
                end = result.text.length();
            }
        } while (copy(result, source, 0, STYLE_ALL));
        return new InsertResult(result.text.toString(), start, end);
    }

    /**
     * Deletes a range while retaining the source styles of the remaining characters.
     */
    public static @NonNull String deleteFromWord(@NonNull String word, int start, int end)
    {
        checkRange(word, start, end);
        Reader source = new Reader(word, 0);
        Writer result = new Writer();
        do
        {
            if (source.offset == start)
                while (source.offset < end)
                    copy(null, source, 0, STYLE_ALL);
        } while (copy(result, source, 0, STYLE_ALL));
        return result.text.toString();
    }

    /**
     * Applies (existingStyle AND styleAnd) OR styleOr to a range. Only the low four
     * bits are embedded. Returns the normalized word and the cursor's new offset.
     * A cursor at a newly emitted marker is moved past that marker to the text.
     */
    public static @NonNull StyleResult applyStyleToWord(
            @NonNull String word,
            int styleOr,
            int styleAnd,
            int start,
            int end,
            int cursorOffset)
    {
        checkRange(word, start, end);
        checkOffset(word, cursorOffset);
        Reader source = new Reader(word, 0);
        Writer result = new Writer();
        int and = STYLE_ALL;
        int or = 0;
        int newCursor = 0;
        do
        {
            if (source.offset == start)
            {
                and = styleAnd;
                or = styleOr;
            }
            if (source.offset == end)
            {
                and = STYLE_ALL;
                or = 0;
            }
            if (source.offset == cursorOffset)
                newCursor = result.text.length();
        } while (copy(result, source, or, and));
        return new StyleResult(result.text.toString(), newCursor);
    }

    /**
     * Returns the style established strictly before the supplied UTF-16 offset.
     */
    public static int getStyleFromWord(@NonNull String word, int offset)
    {
        checkOffset(word, offset);
        int style = 0;
        for (int i = 0; i < offset; )
        {
            int codePoint = word.codePointAt(i);
            i += Character.charCount(codePoint);
            if (Character.isISOControl(codePoint))
                style = codePoint & STYLE_ALL;
        }
        return style;
    }

    /**
     * Creates one embedded style character from the low four style bits.
     */
    public static @NonNull String createStyleByte(int style)
    {
        return String.valueOf((char) ((style & STYLE_ALL) | STYLE_MARKER));
    }

    private static boolean isControlCode(int codePoint)
    {
        return codePoint >= 0 && codePoint <= 31;
    }

    private static void checkOffset(@NonNull String word, int offset)
    {
        if (offset < 0 || offset > word.length())
            throw new IndexOutOfBoundsException("word offset: " + offset);
        if (offset > 0 && offset < word.length() &&
                Character.isHighSurrogate(word.charAt(offset - 1)) &&
                Character.isLowSurrogate(word.charAt(offset)))
            throw new IllegalArgumentException("offset splits a surrogate pair: " + offset);
    }

    private static void checkRange(@NonNull String word, int start, int end)
    {
        checkOffset(word, start);
        checkOffset(word, end);
        if (start > end)
            throw new IllegalArgumentException("range starts after its end");
    }

    /**
     * Copies a code point or consumes a style, emitting only necessary style changes.
     */
    private static boolean copy(
            @Nullable Writer destination,
            @NonNull Reader source,
            int styleOr,
            int styleAnd)
    {
        if (source.offset == source.text.length())
            return false;
        int oldOffset = source.offset;
        int codePoint = source.text.codePointAt(source.offset);
        source.offset += Character.charCount(codePoint);
        if (Character.isISOControl(codePoint))
        {
            source.style = codePoint & STYLE_ALL;
            return true;
        }
        if (destination != null)
        {
            int style = ((source.style & styleAnd) | styleOr) & STYLE_ALL;
            if (destination.style != style)
            {
                destination.text.append((char) (style | STYLE_MARKER));
                destination.style = style;
                // Revisit this character so offset/cursor tracking sees the emitted marker.
                source.offset = oldOffset;
                return true;
            }
            destination.text.appendCodePoint(codePoint);
        }
        return true;
    }

    /**
     * Draws a styled word through the display supplied to the constructor.
     */
    public int writeStyled(
            int x,
            int y,
            @NonNull String word,
            int oldAttributes,
            int reverseOn,
            int reverseOff,
            int defaultStyle)
    {
        return writeStyled(
                x,
                y,
                word,
                oldAttributes,
                reverseOn,
                reverseOff,
                defaultStyle,
                renderer);
    }

    /**
     * Java drawing operations; cell widths are supplied by the caller's renderer.
     */
    public interface Renderer
    {
        void setAttributes(int attributes);

        void writeCodePoint(int x, int y, int codePoint);

        int width(int codePoint);
    }

    public record StyledRun(int style, @NonNull String text)
    {
    }

    public record InsertResult(@NonNull String word, int startOffset, int endOffset)
    {
    }

    public record StyleResult(@NonNull String word, int cursorOffset)
    {
    }

    private static final class Reader
    {
        final @NonNull String text;
        int offset;
        int style;

        Reader(@NonNull String text, int style)
        {
            this.text = text;
            this.style = style & STYLE_ALL;
        }
    }

    private static final class Writer
    {
        final StringBuilder text = new StringBuilder();
        int style;
    }
}
