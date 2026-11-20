/* © 2008 David Given.
 * WordGrinder is licensed under the MIT open source license. See the COPYING
 * file in this distribution for the full text.
 */

package com.cowlark.wordgrinder.eventbus;


/**
 * Unique, opaque handle returned for each listener registration.
 * Pass it to {@link EventBus#removeEventListener(EventToken)} to unregister that listener.
 * Registering the same callback again produces a different token; removing one registration
 * does not remove the others. A token belongs to the bus that created it.
 */
public final class EventToken
{
    final EventBus owner;
    final Class<? extends Event> eventType;

    EventToken(EventBus owner, Class<? extends Event> eventType)
    {
        this.owner = owner;
        this.eventType = eventType;
    }
}
