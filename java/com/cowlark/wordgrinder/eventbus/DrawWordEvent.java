/* © 2008 David Given.
 * WordGrinder is licensed under the MIT open source license. See the COPYING
 * file in this distribution for the full text.
 */

package com.cowlark.wordgrinder.eventbus;


/**
 * Fired before a word is drawn. Listeners may change the word and its rendering styles;
 * the caller uses the modified fields after synchronous delivery has finished.
 */
public final class DrawWordEvent extends Event
{
    /**
     * The word text.
     */
    public String word;

    /**
     * Attributes returned by rendering the preceding word, used for inter-word spacing.
     */
    public int oldStyle;

    /**
     * Default display style applied in addition to the word's embedded styles.
     */
    public int currentStyle;

    /**
     * Whether the word is marked as the first word of a sentence.
     */
    public boolean firstWord;

    public DrawWordEvent(String word, int oldStyle, int currentStyle, boolean firstWord)
    {
        this.word = word;
        this.oldStyle = oldStyle;
        this.currentStyle = currentStyle;
        this.firstWord = firstWord;
    }
}
