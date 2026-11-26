package com.cowlark.wordgrinder.document;

/** A zero-based document position with a UTF-16 offset into its word. */
public record Position(int paragraph, int word, int offset) implements Comparable<Position>
{
    @Override
    public int compareTo(Position other)
    {
        int result = Integer.compare(paragraph, other.paragraph);
        if (result == 0)
            result = Integer.compare(word, other.word);
        if (result == 0)
            result = Integer.compare(offset, other.offset);
        return result;
    }
}
