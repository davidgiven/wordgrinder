package com.cowlark.wordgrinder.eventbus;

import java.util.ArrayList;
import java.util.List;

/** Fired synchronously while collecting fields for the status bar. */
public final class BuildStatusBarEvent extends Event
{
    /* Listeners append fields before the renderer sorts them by priority. */
    public final List<Field> fields = new ArrayList<>();

    /** Text and sort priority for one right-aligned status-bar field. */
    public record Field(int priority, String value)
    {
    }
}
