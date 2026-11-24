package com.cowlark.wordgrinder.eventbus;

/** Fired before typed text is inserted; listeners may replace the text. */
public final class KeyTypedEvent extends Event
{
    /* Carry mutable text through synchronous event delivery. */
    public String value;

    public KeyTypedEvent(String value)
    {
        this.value = value;
    }
}
