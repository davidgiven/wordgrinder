package com.cowlark.wordgrinder.app;

import com.cowlark.wordgrinder.document.Word;
import com.cowlark.wordgrinder.eventbus.EventBus;
import com.cowlark.wordgrinder.eventbus.Idle;
import com.cowlark.wordgrinder.eventbus.KeyTyped;
import com.cowlark.wordgrinder.eventbus.WaitingForUser;
import com.cowlark.wordgrinder.nativeinterface.Screen;
import com.cowlark.wordgrinder.nativeinterface.Screen.InputEvent;
import com.cowlark.wordgrinder.nativeinterface.Screen.KeyInputEvent;
import com.cowlark.wordgrinder.nativeinterface.Screen.MouseInputEvent;
import com.cowlark.wordgrinder.ui.Ui;
import com.cowlark.wordgrinder.ui.Widget.Action;
import com.cowlark.wordgrinder.ui.WrappedLabelWidget;
import com.google.common.collect.ImmutableMap;
import java.io.PrintWriter;
import java.io.StringWriter;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * The word-processor input loop, translated from main.lua.
 */
public class WordProcessor
{
    /* Retain the injected UI, renderer and application event bus. */
    private final Ui ui;
    private final Screen screen;
    private final Word wordRenderer;
    private final EventBus eventBus;
    private static final double IDLE_TIME = (Ui.BLINK_ON_TIME + Ui.BLINK_OFF_TIME) * 5;

    /* Keep redraw requests and transient messages with the loop that consumes them. */
    private boolean redrawPending = true;
    private final List<String> messages = new ArrayList<>();

    /* Mouse selection tracks the initial press across subsequent drag and release events. */
    private boolean oldMouseButton;
    private int oldMouseX;
    private int oldMouseY;

    public WordProcessor(Ui ui, Word wordRenderer, EventBus eventBus)
    {
        this.ui = ui;
        screen = ui.getScreen();
        this.wordRenderer = wordRenderer;
        this.eventBus = eventBus;
    }

    /**
     * Requests a redraw before the next input wait.
     */
    public void queueRedraw()
    {
        redrawPending = true;
    }

    /**
     * Adds a transient message and schedules its display.
     */
    public void nonmodalMessage(String text)
    {
        messages.add(text);
        queueRedraw();
    }

    /**
     * Clears messages after input other than a resize event, matching Lua.
     */
    public void resetNonmodalMessages()
    {
        messages.clear();
    }

    /* Grouped callbacks intentionally do nothing until command dispatch is ported. */
    private Runnable groupCallback(Runnable... callbacks)
    {
        return () -> {
        };
    }

    /* Document wrapping and viewport layout will be supplied by the document renderer. */
    protected void resizeScreen()
    {
        /* TODO: Port ResizeScreen once document layout is available. */
    }

    /* Draw the available desktop and messages; document and status-bar rendering are pending. */
    protected void redrawScreen()
    {
        ui.setColour(null, "Desktop");
        screen.clearScreen();

        /* Stack messages upwards from the bottom, with the newest message last on screen. */
        int[] size = screen.getScreenSize();
        int y = size[1] - 1;
        if (!messages.isEmpty())
        {
            ui.setColour("MessageFG", "MessageBG");
            screen.setReverse();
            for (int i = messages.size() - 1; i >= 0 && y >= 0; i--, y--)
            {
                screen.clearArea(0, y, size[0] - 1, y);
                screen.write(0, y, messages.get(i));
            }
            screen.setNormal();
        }
    }

    /* Master bindings take precedence over printable input and future menu accelerators. */
    private void handleKeyEvent(String key, Map<String, Runnable> masterKeymap)
    {
        Runnable callback = masterKeymap.get(key);
        if (callback != null)
            callback.run();
        else if (!key.startsWith("KEY_"))
        {
            /* TODO: Cmd.Checkpoint() and Cmd.TypeWhileSelected(). */
            KeyTyped payload = new KeyTyped(key);
            eventBus.fireEvent(payload);
            /* TODO: Cmd.InsertStringIntoWord(payload.value). */
        } else
        {
            /* Menu accelerator lookup is deferred until menus are ported. */
            nonmodalMessage(key.substring(4) + " is not bound --- try ESCAPE for a menu");
        }
    }

    /* Preserve click-versus-drag state while document selection commands remain unported. */
    private void handleMouseEvent(MouseInputEvent mouse)
    {
        if (mouse.b())
        {
            if (!oldMouseButton)
            {
                oldMouseX = mouse.x();
                oldMouseY = mouse.y();
                /* TODO: Cmd.UnsetMark(), Cmd.GotoXYPosition(x, y), Cmd.SetMark(). */
            } else
            {
                /* TODO: Cmd.GotoXYPosition(mouse.x(), mouse.y()). */
            }
        }
        if (!mouse.b() && oldMouseButton && mouse.x() == oldMouseX && mouse.y() == oldMouseY)
        {
            /* TODO: Cmd.UnsetMark(). */
        }
        oldMouseButton = mouse.b();
    }

    /* Flush deferred events before waiting, and keep servicing idle timeouts until input arrives
    . */
    private void eventLoop(Map<String, Runnable> masterKeymap)
    {
        while (true)
        {
            /* Document-set change tracking is deferred until DocumentSet is ported. */
            eventBus.flushAsyncEvents();
            eventBus.fireEvent(new WaitingForUser());
            InputEvent input;
            do
            {
                if (redrawPending)
                {
                    redrawScreen();
                    redrawPending = false;
                }
                input = ui.getCharWithBlinkingCursor(IDLE_TIME);
                if (input.isKey("KEY_TIMEOUT"))
                    eventBus.fireEvent(new Idle());
            } while (input.isKey("KEY_TIMEOUT"));

            /* Resizes retain transient messages; all other input dismisses them. */
            if (!input.isKey("KEY_RESIZE"))
                resetNonmodalMessages();
            if (input instanceof MouseInputEvent mouse)
                handleMouseEvent(mouse);
            else if (input instanceof KeyInputEvent key)
                handleKeyEvent(key.key(), masterKeymap);

            /* Match Lua's cancellation before attempting the eventual quit command. */
            if (ui.isQuitting())
            {
                ui.cancelQuit();
                /* TODO: Cmd.TerminateProgram(). */
            }
        }
    }

    /* Use the existing form widgets for the recoverable internal-error dialogue. */
    protected void modalMessage(String title, String text)
    {
        ui
                .newForm()
                .setTitle(title)
                .setHeight(2)
                .setStretchy(true)
                .setRedraw(this::redrawScreen)
                .setHelpText("press SPACE to continue")
                .on(" ", Action.CONFIRM)
                .add(new WrappedLabelWidget(wordRenderer, eventBus)
                        .setBounds(1, 1, -1, -3)
                        .setValue(text))
                .run();
        queueRedraw();
    }

    /**
     * Runs the main input loop on an already initialised screen, recovering from exceptions.
     */
    public void run()
    {
        /* Cmd-based groups remain inert, including resize's grouped redraw callback. */
        ImmutableMap<String, Runnable> masterKeymap = ImmutableMap
                .<String, Runnable>builder()
                .put("KEY_RESIZE", groupCallback(this::resizeScreen, this::redrawScreen))
                .put("KEY_REDRAW", this::redrawScreen)
                .put(
                        " ",
                        groupCallback()) /* Cmd.Checkpoint, TypeWhileSelected, SplitCurrentWord.
                 */.put("KEY_RETURN", groupCallback()) /* Cmd.Checkpoint, TypeWhileSelected,
                        SplitCurrentParagraph. */.put(
                        "KEY_ESCAPE",
                        groupCallback()) /* Cmd.ActivateMenu. */.put(
                        "KEY_MENU",
                        groupCallback()) /* Cmd.ActivateMenu. */.put(
                        "KEY_QUIT",
                        groupCallback()) /* Cmd.TerminateProgram. */.build();

        /* Keep the welcome message and restart after reporting an internal error. */
        nonmodalMessage("Welcome to WordGrinder! Press ESC to show the menu.");
        while (true)
        {
            try
            {
                eventLoop(masterKeymap);
            } catch (Exception e)
            {
                StringWriter traceback = new StringWriter();
                e.printStackTrace(new PrintWriter(traceback));
                java.lang.System.out.print(traceback);
                modalMessage(
                        "Internal error!",
                        "Something went wrong inside WordGrinder! I'll try and " +
                                "continue but you should save your work immediately (under a " +
                                "different filename), exit, and send the following technical " +
                                "information to the author:\n\n" + traceback);
            }
        }
    }
}
