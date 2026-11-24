package com.cowlark.wordgrinder.eventbus;

/** Triggers a redraw. */
public class RedrawEvent extends Event
{
    public static RedrawEvent INSTANCE = new RedrawEvent();
}
