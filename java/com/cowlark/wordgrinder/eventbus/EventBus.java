/* © 2008 David Given.
 * WordGrinder is licensed under the MIT open source license. See the COPYING
 * file in this distribution for the full text.
 */

package com.cowlark.wordgrinder.eventbus;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.function.Consumer;
import org.jspecify.annotations.NonNull;

/**
 * Typed equivalent of the Lua event bus. Each instance owns its listeners and queue.
 * Dispatch matches the concrete event class exactly; base-class listeners do not receive subclasses.
 * Listener order is unspecified. Use the bus from one thread.
 */
public final class EventBus
{
    /** Creates an independent bus with no listeners or pending events. */
    public EventBus() {}

    private final Map<Class<? extends Event>, Map<EventToken, Listener<?>>> listeners = new LinkedHashMap<>();
    private final Map<Class<? extends Event>, Event> batched = new LinkedHashMap<>();

    private record Listener<T extends @NonNull Event>(@NonNull Class<T> type, @NonNull EventCallback<T> callback, @NonNull EventToken token)
    {
        void invoke(@NonNull Event event)
        {
            callback.invoke(type.cast(event), token);
        }
    }

    /**
     * Adds a listener for a particular event class.
     * The supplied callback is called for events whose concrete class is {@code eventType}.
     * The order in which listeners are called is not defined. A callback may be registered
     * more than once or for multiple compatible event types, each with its own token.
     *
     * <p>The returned token is unique for every registration and can be used to unregister
     * that listener. The callback also receives its token, allowing it to unregister itself.
     * Event parameters are carried by the event object rather than separate arguments.
     *
     * @param <T> the event type accepted by the callback
     * @param eventType the concrete event class to register for
     * @param callback the callback to register
     * @return the unique token for this registration
     */
    public <T extends @NonNull Event> @NonNull EventToken addEventListener(@NonNull Class<T> eventType, @NonNull EventCallback<T> callback)
    {
        EventToken token = new EventToken(this, eventType);
        // Ensure there is a listener table for this class, then register the callback.
        listeners.computeIfAbsent(eventType, key -> new LinkedHashMap<>())
            .put(token, new Listener<>(eventType, callback, token));
        return token;
    }

    /**
     * Adds a listener that receives only the event object.
     * Registration and removal behave as for {@link #addEventListener(Class, EventCallback)};
     * the callback does not receive its registration token.
     *
     * @param <T> the event type accepted by the callback
     * @param eventType the concrete event class to register for
     * @param callback the callback to register
     * @return the unique token for this registration
     */
    public <T extends @NonNull Event> @NonNull EventToken addEventListener(@NonNull Class<T> eventType, @NonNull Consumer<? super T> callback)
    {
        return addEventListener(eventType, (event, token) -> callback.accept(event));
    }

    /**
     * Removes the listener identified by a callback token from its event class.
     * Removing an already-removed token or a token from another bus has no effect.
     *
     * @param token a token returned by {@code addEventListener}
     */
    public void removeEventListener(@NonNull EventToken token)
    {
        if (token.owner != this)
            return;
        Map<EventToken, Listener<?>> registered = listeners.get(token.eventType);
        if (registered != null)
        {
            registered.remove(token);
            if (registered.isEmpty())
                listeners.remove(token.eventType);
        }
    }

    /**
     * Fires an event synchronously.
     * Any callbacks registered for its concrete class are called, in an unspecified order,
     * with the event object and, where requested, their registration token.
     * If no listeners are registered, nothing happens.
     *
     * <p>A listener added during dispatch waits for a subsequent delivery; a listener removed
     * before its turn is skipped. Callbacks may fire further events synchronously.
     * An exception from a callback propagates to the caller and stops the current delivery.
     *
     * @param event the event to fire, including its payload
     */
    public void fireEvent(@NonNull Event event)
    {
        Map<EventToken, Listener<?>> registered = listeners.get(event.getClass());
        if (registered == null)
            return;
        for (Listener<?> listener : new ArrayList<>(registered.values()))
        {
            if (registered.containsKey(listener.token()))
                listener.invoke(event);
        }
    }

    /**
     * Queues an asynchronous event for delivery at the end of the application's event loop.
     * Events are batched by concrete class: queuing the same class again replaces the pending
     * instance, so the most recently queued payload wins. Delivery order is unspecified.
     *
     * <p>No background thread is started. The event loop must call {@link #flushAsyncEvents()}.
     * Unlike the original Lua API, queued events can carry parameters in their event object.
     *
     * @param event the event to queue, including its payload
     */
    public void fireAsyncEvent(@NonNull Event event)
    {
        batched.put(event.getClass(), event);
    }

    /**
     * Flushes pending asynchronous events until the queue is empty.
     * It is safe for an event handler to queue more events, including another instance of the
     * class currently being delivered. Those events are delivered during this flush too.
     *
     * <p>Each pending event is removed before being fired. If a callback throws, that event
     * has been consumed, the exception propagates, and other pending events remain queued
     * for a later flush.
     */
    public void flushAsyncEvents()
    {
        while (!batched.isEmpty())
        {
            var iterator = batched.entrySet().iterator();
            Event event = iterator.next().getValue();
            // Remove before dispatch so a handler can queue this event class again.
            iterator.remove();
            fireEvent(event);
        }
    }
}
