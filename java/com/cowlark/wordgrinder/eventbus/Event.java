/* © 2008 David Given.
 * WordGrinder is licensed under the MIT open source license. See the COPYING
 * file in this distribution for the full text.
 */

package com.cowlark.wordgrinder.eventbus;

/**
 * Base class for application events. Each concrete subclass defines an event type and its payload.
 */
public abstract class Event
{
    /**
     * Constructs an event for delivery through an {@link EventBus}.
     */
    protected Event()
    {
    }
}
