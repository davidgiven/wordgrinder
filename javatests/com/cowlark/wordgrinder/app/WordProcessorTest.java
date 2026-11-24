package com.cowlark.wordgrinder.app;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertSame;
import static org.junit.Assert.assertThrows;
import static org.junit.Assert.assertTrue;

import com.cowlark.wordgrinder.document.Document;
import com.cowlark.wordgrinder.document.DocumentStyle;
import com.cowlark.wordgrinder.document.Paragraph;
import com.cowlark.wordgrinder.document.Word;
import com.cowlark.wordgrinder.eventbus.*;
import com.cowlark.wordgrinder.nativeinterface.Display;
import com.cowlark.wordgrinder.nativeinterface.Screen;
import com.cowlark.wordgrinder.nativeinterface.Screen.InputEvent;
import com.cowlark.wordgrinder.nativeinterface.Screen.KeyInputEvent;
import com.cowlark.wordgrinder.nativeinterface.Screen.MouseInputEvent;
import com.cowlark.wordgrinder.ui.MenuTree;
import com.cowlark.wordgrinder.ui.Ui;
import com.cowlark.wordgrinder.ui.Action;
import com.cowlark.wordgrinder.ui.Action.ActionResult;
import com.cowlark.wordgrinder.utils.Injector;
import org.junit.Test;
import java.lang.reflect.Proxy;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.List;
import java.util.Queue;

public class WordProcessorTest
{
    /* New editors can navigate immediately with the cursor on a blank word. */
    @Test
    public void startsWithOneSelectedDocumentAndOneBlankParagraph()
    {
        Fixture fixture = new Fixture();
        var set = fixture.processor.getDocumentSet();
        Document current = fixture.processor.getCurrentDocument();

        /* Use the same document for the selection, list and name index. */
        assertEquals(List.of(current), set.documents);
        assertSame(current, set.documentIndex.get("main"));
        assertEquals(1, current.paragraphs.size());
        assertEquals(List.of(""), current.paragraphs.getFirst().words);
        assertSame(ActionResult.SUCCEEDED, new Navigation.GotoEndOfDocumentAction(fixture.processor).execute());
        assertEquals(1, current.cursorOffset);
    }

    /* Preserve one-based offsets while moving over supplementary Unicode characters. */
    @Test
    public void navigationMovesOverCodePointsAndAcrossParagraphs()
    {
        Fixture fixture = new Fixture();
        Document document = fixture.processor.getCurrentDocument();
        document.paragraphs.set(0, fixture.paragraph("first", "😀z"));
        document.paragraphs.add(fixture.paragraph("last"));
        document.cursorWord = 2;

        /* Moving back within the second word must stay in that word. */
        assertSame(ActionResult.SUCCEEDED, new Navigation.GotoNextCharAction(fixture.processor).execute());
        assertEquals(3, document.cursorOffset);
        assertSame(ActionResult.SUCCEEDED, new Navigation.GotoPreviousWordAction(fixture.processor).execute());
        assertEquals(2, document.cursorWord);
        assertEquals(1, document.cursorOffset);

        /* A wrapped character move at the end of the word enters the next paragraph. */
        new Navigation.GotoEndOfWordAction(fixture.processor).execute();
        assertSame(ActionResult.SUCCEEDED, new Navigation.GotoNextCharWAction(fixture.processor).execute());
        assertEquals(2, document.cursorParagraph);
        assertEquals(1, document.cursorWord);
        assertEquals(1, document.cursorOffset);
        assertSame(ActionResult.FAILED, new Navigation.GotoNextParagraphAction(fixture.processor).execute());
    }

    /* Join styled text across a paragraph boundary and mark the document set dirty. */
    @Test
    public void navigationDeletesAcrossParagraphBoundaries()
    {
        Fixture fixture = new Fixture();
        Document document = fixture.processor.getCurrentDocument();
        String bold = Word.createStyleByte(Word.BOLD);
        document.paragraphs.set(0, fixture.paragraph(bold + "first"));
        document.paragraphs.add(fixture.paragraph("second", "third"));
        document.cursorOffset = bold.length() + "first".length() + 1;

        /* Delete at the word end to merge it with the first word of the next paragraph. */
        assertSame(ActionResult.SUCCEEDED, new Navigation.DeleteNextCharAction(fixture.processor).execute());
        assertEquals(1, document.paragraphs.size());
        assertEquals(List.of(bold + "first" + Word.createStyleByte(0) + "second", "third"),
                document.paragraphs.getFirst().words);
        assertEquals(bold.length() + "first".length() + 1, document.cursorOffset);
        assertTrue(fixture.processor.getDocumentSet().changed);
        assertTrue(fixture.processor.getDocumentSet().justChanged);
    }

    /* Flush deferred events before waiting and defer idle redraws until the next loop pass. */
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
                    fixture.bus.fireAsyncEvent(RedrawEvent.INSTANCE);
                    assertEquals(1, fixture.redraws);
                });
        fixture.bus.addEventListener(
                KeyTypedEvent.class, event -> {
                    assertEquals(1, fixture.redraws);
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

    /* Master bindings consume input and closing the menu queues a redraw. */
    @Test
    public void masterBindingsOverrideTypingAndMenuCloseQueuesRedraw()
    {
        Fixture fixture = new Fixture();
        List<String> typed = new ArrayList<>();
        fixture.bus.addEventListener(KeyTypedEvent.class, event -> typed.add(event.value));
        fixture.keys(
                "KEY_RESIZE",
                " ",
                "KEY_RETURN",
                "KEY_ESCAPE",
                "KEY_ESCAPE",
                "KEY_MENU",
                "KEY_QUIT",
                "KEY_REDRAW");
        fixture.run();
        assertTrue(typed.isEmpty());
        assertTrue(fixture.processor.dialogues.isEmpty());
        assertEquals(5, fixture.redraws);
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
                    {
                        /* Repaint the retained warning before the next input dismisses it. */
                        int redraws = fixture.redraws;
                        fixture.bus.fireEvent(RedrawEvent.INSTANCE);
                        assertEquals(redraws + 1, fixture.redraws);
                    }
                });
        fixture.keys("KEY_UNKNOWN", "KEY_RESIZE", "x", "KEY_REDRAW");
        fixture.run();
        assertEquals(
                List.of(
                        "Welcome to WordGrinder! Press ESC to show the menu.",
                        "UNKNOWN is not bound --- try ESCAPE for a menu",
                        "UNKNOWN is not bound --- try ESCAPE for a menu",
                        "UNKNOWN is not bound --- try ESCAPE for a menu"), fixture.writes);
        assertEquals(5, fixture.redraws);
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

        /* Record mouse dispatch independently of the unimplemented navigation command. */
        List<String> positions = new ArrayList<>();
        var original = Action.of(Navigation.GotoXYPositionAction.class);
        Injector.INSTANCE.bindInstance(Navigation.GotoXYPositionAction.class,
                new Navigation.GotoXYPositionAction(fixture.processor)
                {
                    @Override
                    public ActionResult execute(int x, int y)
                    {
                        positions.add(x + "," + y);
                        return ActionResult.SUCCEEDED;
                    }
                });
        try
        {
            fixture.run();
        }
        finally
        {
            Injector.INSTANCE.bindInstance(Navigation.GotoXYPositionAction.class, original);
        }

        /* Press and drag move the cursor, and printable input still reaches the event bus. */
        assertEquals(List.of("2,3", "4,5"), positions);
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
        /* Record recovery dialogues and share the production redraw event path. */
        final List<String> dialogues = new ArrayList<>();
        private final EventBus bus;

        /* Register the recording subclass under the type used by injected actions. */
        RecordingProcessor(Injector injector, Ui ui, Screen screen, Word renderer, EventBus bus)
        {
            /* Navigation is unused by the input-loop scenarios in this fixture. */
            super(injector, ui, screen, renderer, bus, null, new MenuTree(ui, renderer, bus));
            this.bus = bus;

            /* Supply the fixture dependencies when actions resolve them through the injector. */
            injector.bindInstance(Screen.class, screen);
            injector.bindInstance(Ui.class, ui);
            injector.bindInstance(Word.class, renderer);
            injector.bindInstance(EventBus.class, bus);
            injector.bindInstance(WordProcessor.class, this);

            /* Replace shared actions that retain dependencies from the previous fixture. */
            Injector.INSTANCE.bindInstance(WordProcessor.class, this);
            Injector.INSTANCE.bindInstance(RedrawScreenAction.class, injector.create(RedrawScreenAction.class));
            Injector.INSTANCE.bindInstance(ActivateMenuAction.class, injector.create(ActivateMenuAction.class));
        }

        @Override
        protected void modalMessage(String title, String text)
        {
            dialogues.add(title + "\n" + text);
            bus.fireEvent(RedrawEvent.INSTANCE);
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
                        case "useUnicode" -> false;
                        case "getStringWidth" -> ((String) args[0]).length();
                        case "getBoundedString" ->
                        {
                            String text = (String) args[0];
                            yield text.substring(0, Math.min(text.length(), (int) args[1]));
                        }
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

        /* Build model paragraphs with the same rendering environment as the editor. */
        Paragraph paragraph(String... words)
        {
            return Paragraph.builder(screen, new Word(display), bus)
                    .setDocumentStyle(new DocumentStyle("Paragraph", "P", 0, 0, null, null,
                            null, null, null, null))
                    .setWords(words)
                    .build();
        }

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
