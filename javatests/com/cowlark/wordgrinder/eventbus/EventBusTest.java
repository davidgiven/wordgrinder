package com.cowlark.wordgrinder.eventbus;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotSame;
import static org.junit.Assert.assertThrows;
import static org.junit.Assert.assertTrue;

import org.junit.Test;
import java.util.ArrayList;
import java.util.List;

/**
 * Regression tests for typed event dispatch, listener registration, and async batching.
 */
public final class EventBusTest
{
    @Test
    public void typedDispatchAndTokens()
    {
        EventBus bus = new EventBus();
        List<Integer> values = new ArrayList<>();
        EventToken first = bus.addEventListener(Changed.class, event -> values.add(event.value));
        EventToken second = bus.addEventListener(
                Changed.class, (event, token) -> {
                    values.add(event.value * 10);
                    bus.removeEventListener(token);
                });
        assertNotSame(first, second);
        bus.fireEvent(new Idle());
        bus.fireEvent(new SpecialChanged());
        assertTrue(values.isEmpty());
        bus.fireEvent(new Changed(2));
        assertEquals(2, values.size());
        assertTrue(values.contains(2) && values.contains(20));
        values.clear();
        bus.fireEvent(new Changed(3));
        assertEquals(List.of(3), values);
        bus.removeEventListener(first);
        bus.removeEventListener(first);
        bus.fireEvent(new Changed(4));
        assertEquals(List.of(3), values);
    }

    @Test
    public void changesDuringDispatch()
    {
        EventBus bus = new EventBus();
        List<String> calls = new ArrayList<>();
        List<EventToken> tokens = new ArrayList<>();
        tokens.add(bus.addEventListener(
                Changed.class, (event, token) -> {
                    calls.add("first");
                    bus.removeEventListener(token);
                    bus.removeEventListener(tokens.get(1));
                    bus.addEventListener(Changed.class, next -> calls.add("new"));
                }));
        tokens.add(bus.addEventListener(Changed.class, event -> calls.add("removed")));
        bus.fireEvent(new Changed(1));
        assertEquals(List.of("first"), calls);
        bus.fireEvent(new Changed(2));
        assertEquals(List.of("first", "new"), calls);
    }

    @Test
    public void batchingAndRequeue()
    {
        EventBus bus = new EventBus();
        List<Integer> values = new ArrayList<>();
        bus.addEventListener(
                Changed.class, event -> {
                    values.add(event.value);
                    if (event.value == 2)
                        bus.fireAsyncEvent(new Changed(3));
                });
        bus.fireAsyncEvent(new Changed(1));
        bus.fireAsyncEvent(new Changed(2));
        assertTrue(values.isEmpty());
        bus.flushAsyncEvents();
        assertEquals(List.of(2, 3), values);
        bus.flushAsyncEvents();
        assertEquals(2, values.size());
    }

    @Test
    public void reentrantDispatchAndIsolation()
    {
        EventBus bus = new EventBus();
        EventBus other = new EventBus();
        List<Integer> values = new ArrayList<>();
        EventToken token = bus.addEventListener(
                Changed.class, event -> {
                    values.add(event.value);
                    if (event.value == 1)
                        bus.fireEvent(new Changed(2));
                });
        other.removeEventListener(token);
        other.fireEvent(new Changed(0));
        bus.fireEvent(new Changed(1));
        assertEquals(List.of(1, 2), values);
    }

    @Test
    public void exceptionsLeaveOtherEventsQueued()
    {
        EventBus bus = new EventBus();
        List<String> calls = new ArrayList<>();
        bus.addEventListener(
                Changed.class, event -> {
                    throw new IllegalStateException();
                });
        bus.addEventListener(Idle.class, event -> calls.add("idle"));
        bus.fireAsyncEvent(new Changed(1));
        bus.fireAsyncEvent(new Idle());
        assertThrows(IllegalStateException.class, bus::flushAsyncEvents);
        assertTrue(calls.isEmpty());
        bus.flushAsyncEvents();
        assertEquals(List.of("idle"), calls);
    }

    @Test
    public void drawWordListenersCanUpdateTheRenderingPayload()
    {
        EventBus bus = new EventBus();
        DrawWord event = new DrawWord("word", 2, 8, true);
        bus.addEventListener(
                DrawWord.class, payload -> {
                    assertEquals("word", payload.word);
                    assertEquals(2, payload.oldStyle);
                    assertEquals(8, payload.currentStyle);
                    assertTrue(payload.firstWord);
                    payload.word = "replacement";
                    payload.oldStyle = 0;
                    payload.currentStyle |= 32;
                    payload.firstWord = false;
                });
        bus.fireEvent(event);
        assertEquals("replacement", event.word);
        assertEquals(0, event.oldStyle);
        assertEquals(40, event.currentStyle);
        assertTrue(!event.firstWord);
    }

    private static class Changed extends Event
    {
        final int value;

        Changed(int value)
        {
            this.value = value;
        }
    }

    private static final class SpecialChanged extends Changed
    {
        SpecialChanged()
        {
            super(0);
        }
    }

    private static final class Idle extends Event
    {
    }
}
