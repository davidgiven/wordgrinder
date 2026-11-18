/* © 2008 David Given.
 * WordGrinder is licensed under the MIT open source license. See the COPYING
 * file in this distribution for the full text.
 */

package com.cowlark.wordgrinder.eventbus;

import org.jspecify.annotations.NonNull;

/**
 * Callback registered for an event class. The payload is carried by the event object,
 * rather than expanded into additional callback arguments as in Lua.
 *
 * @param <T> the event type accepted by the callback
 */
@FunctionalInterface
public interface EventCallback<T extends @NonNull Event>
{
    /**
     * Handles an event delivered by the bus.
     *
     * @param event the event being fired, including its payload
     * @param token the unique registration token, which can be used to remove this listener
     */
    void invoke(@NonNull T event, @NonNull EventToken token);
}
