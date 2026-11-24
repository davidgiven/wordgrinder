package com.cowlark.wordgrinder.app;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertThrows;
import static org.junit.Assert.assertTrue;

import com.cowlark.wordgrinder.document.Word;
import com.cowlark.wordgrinder.eventbus.*;
import com.cowlark.wordgrinder.nativeinterface.Display;
import com.cowlark.wordgrinder.nativeinterface.Screen;
import com.cowlark.wordgrinder.nativeinterface.Screen.InputEvent;
import com.cowlark.wordgrinder.nativeinterface.Screen.KeyInputEvent;
import com.cowlark.wordgrinder.nativeinterface.Screen.MouseInputEvent;
import com.cowlark.wordgrinder.ui.Ui;
import com.cowlark.wordgrinder.utils.Injector;
import org.junit.Test;
import java.lang.reflect.Proxy;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.List;
import java.util.Queue;

public class WordProcessorTest
{
    /* Deferred events precede WaitingForUser; idle repeats input waiting and services redraws. */
    @Test
    public void dispatchesEventsAndRedrawsAfterIdle()
    {
        Fixture fixture = new Fixture();
        List<String> events = new ArrayList<>();
        fixture.bus.addEventListener(ChangedEvent.class, event -> events.add("changed"));
        fixture.bus.addEventListener(WaitingForUserEvent.class, event -> events.add("waiting"));
        fixture.bus.addEventListener(
                IdleEvent.class, event -> {
                    events.add("idle");
                    fixture.idling = false;
                    fixture.processor.queueRedraw();
                });
        fixture.bus.addEventListener(
                KeyTypedEvent.class, event -> {
                    events.add(event.value);
                    event.value = "replacement";
                });
        fixture.bus.fireAsyncEvent(new ChangedEvent());
        fixture.idling = true;
        fixture.keys("x");
        fixture.run();
        assertEquals(List.of("changed", "waiting", "idle", "x", "waiting"), events);
        assertEquals(2, fixture.redraws);
    }

    /* Every grouped master binding is inert; the direct redraw binding still runs. */
    @Test
    public void masterBindingsOverrideTypingAndGroupsDoNothing()
    {
        Fixture fixture = new Fixture();
        List<String> typed = new ArrayList<>();
        fixture.bus.addEventListener(KeyTypedEvent.class, event -> typed.add(event.value));
        fixture.keys(
                "KEY_RESIZE",
                " ",
                "KEY_RETURN",
                "KEY_ESCAPE",
                "KEY_MENU",
                "KEY_QUIT",
                "KEY_REDRAW");
        fixture.run();
        assertTrue(typed.isEmpty());
        assertEquals(2, fixture.redraws);
    }

    /* Unknown keys replace dismissed messages; resizing retains the current warning. */
    @Test
    public void messagesSurviveResizeAndAreDismissedByOtherInput()
    {
        Fixture fixture = new Fixture();
        int[] waits = {0};
        fixture.bus.addEventListener(
                WaitingForUserEvent.class, event -> {
                    if (++waits[0] == 3)
                        fixture.processor.queueRedraw();
                });
        fixture.keys("KEY_UNKNOWN", "KEY_RESIZE", "x", "KEY_REDRAW");
        fixture.run();
        assertEquals(
                List.of(
                        "Welcome to WordGrinder! Press ESC to show the menu.",
                        "UNKNOWN is not bound --- try ESCAPE for a menu",
                        "UNKNOWN is not bound --- try ESCAPE for a menu"), fixture.writes);
        assertEquals(4, fixture.redraws);
    }

    /* Multiple queued messages appear newest first from the bottom upwards. */
    @Test
    public void messagesQueueOneRedrawAndStackAboveTheWelcomeMessage()
    {
        Fixture fixture = new Fixture();
        fixture.processor.nonmodalMessage("first");
        fixture.processor.nonmodalMessage("second");
        fixture.run();
        assertEquals(
                List.of("Welcome to WordGrinder! Press ESC to show the menu.", "second", "first"),
                fixture.writes);
        assertEquals(1, fixture.redraws);
    }

    /* Mouse events bypass text dispatch, and system quit requests are cancelled after input. */
    @Test
    public void handlesMouseAndCancelsQuitRequests()
    {
        Fixture fixture = new Fixture();
        List<String> typed = new ArrayList<>();
        fixture.bus.addEventListener(KeyTypedEvent.class, event -> typed.add(event.value));
        fixture.input.addAll(List.of(
                new MouseInputEvent(2, 3, true, true),
                new MouseInputEvent(4, 5, true, false),
                new MouseInputEvent(4, 5, false, false)));
        fixture.keys("z");
        fixture.ui.requestQuit();
        fixture.run();
        assertEquals(List.of("z"), typed);
        assertFalse(fixture.ui.isQuitting());
    }

    /* An event-handler failure opens the recovery dialogue, then resumes the event loop. */
    @Test
    public void reportsInternalErrorsAndContinues()
    {
        Fixture fixture = new Fixture();
        List<String> typed = new ArrayList<>();
        fixture.bus.addEventListener(
                KeyTypedEvent.class, event -> {
                    if (event.value.equals("a"))
                        throw new IllegalStateException("test failure");
                    typed.add(event.value);
                });
        fixture.keys("a", "b");
        fixture.run();
        assertEquals(List.of("b"), typed);
        assertEquals(1, fixture.processor.dialogues.size());
        assertTrue(fixture.processor.dialogues
                .get(0)
                .startsWith("Internal error!\nSomething went wrong"));
        assertTrue(fixture.processor.dialogues
                .get(0)
                .contains("IllegalStateException: test failure"));
        assertEquals(2, fixture.redraws);
    }

    /* An Error terminates the intentionally endless loop without entering its recovery handler. */
    private static final class Stop extends Error
    {
    }

    private static class RecordingProcessor extends WordProcessor
    {
        final List<String> dialogues = new ArrayList<>();

        /* Register the recording subclass under the type used by injected actions. */
        RecordingProcessor(Injector injector, Ui ui, Screen screen, Word renderer, EventBus bus)
        {
            /* Navigation is unused by the input-loop scenarios in this fixture. */
            super(injector, ui, screen, renderer, bus, null);
            injector.bindInstance(WordProcessor.class, this);
        }

        @Override
        protected void modalMessage(String title, String text)
        {
            dialogues.add(title + "\n" + text);
            queueRedraw();
        }
    }

    /* Script input independently of cursor blink periods; idle listeners end simulated timeouts. */
    private static class Fixture
    {
        final Queue<InputEvent> input = new ArrayDeque<>();
        final List<String> writes = new ArrayList<>();
        final EventBus bus = new EventBus();
        int redraws;
        boolean idling;
        final Screen screen = (Screen) Proxy.newProxyInstance(
                Screen.class.getClassLoader(),
                new Class<?>[]{Screen.class},
                (proxy, method, args) -> {
                    return switch (method.getName())
                    {
                        case "getScreenSize" -> new int[]{80, 24};
                        case "clearScreen" ->
                        {
                            redraws++;
                            yield null;
                        }
                        case "write" ->
                        {
                            writes.add((String) args[2]);
                            yield null;
                        }
                        case "getEvent" ->
                        {
                            if (idling)
                                yield new KeyInputEvent("KEY_TIMEOUT");
                            if (input.isEmpty())
                                throw new Stop();
                            yield input.remove();
                        }
                        default ->
                        {
                            if (method.getReturnType() != void.class)
                                throw new AssertionError(
                                        "Unexpected screen call: " + method.getName());
                            yield null;
                        }
                    };
                });
        final Ui ui = new Ui(screen);
        final Display display = (Display) Proxy.newProxyInstance(
                Display.class.getClassLoader(),
                new Class<?>[]{Display.class},
                (proxy, method, args) -> {
                    throw new AssertionError("Unexpected display call: " + method.getName());
                });
        final RecordingProcessor processor =
                new RecordingProcessor(new Injector(), ui, screen, new Word(display), bus);

        void keys(String... keys)
        {
            for (String key : keys)
                input.add(new KeyInputEvent(key));
        }

        void run()
        {
            assertThrows(Stop.class, processor::run);
        }
    }
}
