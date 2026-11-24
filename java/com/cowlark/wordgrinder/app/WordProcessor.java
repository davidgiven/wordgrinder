package com.cowlark.wordgrinder.app;

import com.cowlark.wordgrinder.addons.undo.CheckpointAction;
import com.cowlark.wordgrinder.document.Document;
import com.cowlark.wordgrinder.document.DocumentSet;
import com.cowlark.wordgrinder.eventbus.*;
import com.cowlark.wordgrinder.nativeinterface.Screen;
import com.cowlark.wordgrinder.nativeinterface.Screen.InputEvent;
import com.cowlark.wordgrinder.nativeinterface.Screen.KeyInputEvent;
import com.cowlark.wordgrinder.nativeinterface.Screen.MouseInputEvent;
import com.cowlark.wordgrinder.ui.*;
import com.cowlark.wordgrinder.utils.Injector.Inject;
import com.google.common.collect.ImmutableMap;

import java.io.PrintWriter;
import java.io.StringWriter;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;

import static com.cowlark.wordgrinder.ui.Action.ActionResult.SUCCEEDED;
import static java.lang.Math.max;

/**
 * The word-processor input loop, translated from main.lua.
 */
public class WordProcessor
{
    private final Ui ui;
    private final Screen screen;
    private final Navigation navigation;
    private final MenuTree menuTree;

    /* Own the active document set and its per-set preferences. */
    private final DocumentSet documentSet;

    /* Dispatch editor events and determine when the input loop is idle. */
    private final EventBus eventBus;
    private static final double IDLE_TIME = (Ui.BLINK_ON_TIME + Ui.BLINK_OFF_TIME) * 5;

    private final List<String> messages = new ArrayList<>();

    /* Mouse selection tracks the initial press across subsequent drag and release events. */
    private boolean oldMouseButton;
    private int oldMouseX;
    private int oldMouseY;

    /* Receive the editor services and create the initial document set. */
    @Inject
    public WordProcessor(Ui ui, Screen screen, EventBus eventBus, Navigation navigation, MenuTree menuTree)
    {
        this.ui = ui;
        this.screen = screen;
        this.eventBus = eventBus;
        this.navigation = navigation;
        this.menuTree = menuTree;

        /* Create the initial document with the editor's rendering collaborators. */
        this.documentSet = new DocumentSet();
    }

    /** Returns the document set owned by this editor. */
    public DocumentSet getDocumentSet()
    {
        return documentSet;
    }

    /** Returns the current selection in the document set. */
    public Document getCurrentDocument()
    {
        return getDocumentSet().current;
    }

    /**
     * Adds a transient message and schedules its display.
     */
    public void nonmodalMessage(String text)
    {
        messages.add(text);
        queueRedraw();
    }

    /* Schedule a repaint on the next pass through the input loop. */
    void queueRedraw()
    {
        eventBus.fireAsyncEvent(RedrawEvent.INSTANCE);
    }

    /**
     * Clears messages after input other than a resize event, matching Lua.
     */
    public void resetNonmodalMessages()
    {
        messages.clear();
    }

    /* Document wrapping and viewport layout will be supplied by the document renderer. */
    public static class ResizeScreenAction implements VoidAction
    {
        /* Expose this constructor to the action injector. */
        @Inject
        public ResizeScreenAction()
        {
        }


        @Override
        public ActionResult execute()
        {
            return SUCCEEDED;
        }
    }

    /* Draw the desktop, status bar and transient messages. */
    public static class RedrawScreenAction implements VoidAction
    {
        private final WordProcessor wordProcessor;
        private final Ui ui;
        private final Screen screen;

        @Inject
        public RedrawScreenAction(WordProcessor wp)
        {
            wordProcessor = wp;
            ui = wp.ui;
            screen = wp.screen;
        }

        @Override
        public ActionResult execute()
        {
            /* Wait until the backend reports a usable screen before drawing. */
            int[] size = screen.getScreenSize();
            int width = size[0];
            int y = size[1] - 1;
            if (width <= 0 || y < 0)
                return SUCCEEDED;

            ui.setColour(null, "Desktop");
            screen.clearScreen();

            /* Reserve the bottom row for the status bar when enabled. */
            if (wordProcessor.getDocumentSet().statusBar)
                drawStatusBar(width, y--);

            /* Stack messages upwards from the bottom, with the newest message last on screen. */
            if (!wordProcessor.messages.isEmpty())
            {
                ui.setColour("MessageFG", "MessageBG");
                screen.setReverse();
                int i = wordProcessor.messages.size() - 1;
                while (i >= 0 && y >= 0)
                {
                    screen.clearArea(0, y, width - 1, y);
                    screen.write(0, y, wordProcessor.messages.get(i));
                    i--;
                    y--;
                }
                screen.setNormal();
            }

            return SUCCEEDED;
        }

        /* Draw document names and the dirty marker before collecting add-on fields. */
        private void drawStatusBar(int width, int y)
        {
            DocumentSet set = wordProcessor.getDocumentSet();
            String filename = set.name == null ? "(unnamed)" : set.name;
            int separator = max(filename.lastIndexOf('/'), filename.lastIndexOf('\\'));
            String name = set.current.name == null ? "" : set.current.name;
            String label = filename.substring(separator + 1) + "[" + name + "] "
                    + (set.changed ? "CHANGED" : "");
            ui.setColour("StatusbarBG", "StatusbarFG");
            screen.setReverse();
            screen.clearArea(0, y, width - 1, y);
            ui.lAlignInField(0, y, width, label);

            /* Deliver the event now so its fields can be laid out in this redraw. */
            BuildStatusBarEvent event = new BuildStatusBarEvent();
            wordProcessor.eventBus.fireEvent(event);
            event.fields.sort(Comparator.comparingInt(BuildStatusBarEvent.Field::priority));
            if (!event.fields.isEmpty())
            {
                StringBuilder fields = new StringBuilder(" ");
                for (BuildStatusBarEvent.Field field : event.fields)
                    fields.append(" │ ").append(field.value());
                if (fields.charAt(fields.length() - 1) == ' ')
                    fields.setLength(fields.length() - 1);
                ui.rAlignInField(0, y, width, fields.toString());
            }
            screen.setNormal();
        }
    }

    public static class TerminateProgramAction implements VoidAction
    {
        /* Expose this constructor to the action injector. */
        @Inject
        public TerminateProgramAction()
        {
        }

        @Override
        public ActionResult execute()
        {
            return SUCCEEDED;
        }
    }

    /* Master bindings take precedence over printable input and future menu accelerators. */
    private void handleKeyEvent(String key, Map<String, VoidAction> masterKeymap)
    {
        VoidAction action = masterKeymap.get(key);
        if (action != null)
            action.execute();
        else if (!key.startsWith("KEY_"))
        {
            Action.of(CheckpointAction.class).execute();
            /* TODO: Cmd.Checkpoint() and Cmd.TypeWhileSelected(). */
            KeyTypedEvent payload = new KeyTypedEvent(key);
            eventBus.fireEvent(payload);
            /* TODO: Cmd.InsertStringIntoWord(payload.value). */
        }
        else
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
                Action.of(Navigation.GotoXYPositionAction.class).execute(mouse.x(), mouse.y());
                /* TODO: Cmd.UnsetMark(), Cmd.GotoXYPosition(x, y), Cmd.SetMark(). */
            }
            else
            {

                Action.of(Navigation.GotoXYPositionAction.class).execute(mouse.x(), mouse.y());
            }
        }
        if (!mouse.b() && oldMouseButton && mouse.x() == oldMouseX && mouse.y() == oldMouseY)
        {
            /* TODO: Cmd.UnsetMark(). */
        }
        oldMouseButton = mouse.b();
    }

    /* Flush deferred events before waiting, and keep servicing idle timeouts until input arrives. */
    private void eventLoop(Map<String, VoidAction> masterKeymap)
    {
        while (true)
        {
            /* Document-set change tracking is deferred until DocumentSet is ported. */
            eventBus.flushAsyncEvents();
            eventBus.fireEvent(new WaitingForUserEvent());
            InputEvent input;
            do
            {
                input = ui.getCharWithBlinkingCursor(IDLE_TIME);
                if (input.isKey("KEY_TIMEOUT"))
                    eventBus.fireEvent(new IdleEvent());
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
        ui.newForm()
                .setTitle(title)
                .setHeight(2)
                .setStretchy(true)
                .setRedraw(() -> Action.of(RedrawScreenAction.class).execute())
                .setHelpText("press SPACE to continue")
                .on(" ", Widget.Action.CONFIRM)
                .add(new WrappedLabelWidget().setBounds(1, 1, -1, -3).setValue(text))
                .run();
        eventBus.fireEvent(RedrawEvent.INSTANCE);
    }

    public static class ActivateMenuAction implements VoidAction
    {
        private final MenuTree menuTree;
        private final WordProcessor wordProcessor;
        private final EventBus eventBus;

        @Inject
        public ActivateMenuAction(MenuTree menuTree, WordProcessor wordProcessor, EventBus eventBus)
        {
            this.menuTree = menuTree;
            this.wordProcessor = wordProcessor;
            this.eventBus = eventBus;
        }

        @Override
        public ActionResult execute()
        {
            return menuTree.activate(MenuDefinitions.TOPLEVEL,
                    wordProcessor.getDocumentSet().menu,
                    () -> eventBus.fireEvent(RedrawEvent.INSTANCE),
                    wordProcessor::nonmodalMessage);
        }
    }

    /**
     * Runs the main input loop on an already initialised screen, recovering from exceptions.
     */
    public void run()
    {
        eventBus.addEventListener(RedrawEvent.class, e -> Action.of(RedrawScreenAction.class).execute());

        /* Resolve master bindings through the injector when their keys are pressed. */
        ImmutableMap<String, VoidAction> masterKeymap = ImmutableMap.<String, VoidAction>builder()
                .put("KEY_RESIZE", Action.of(ResizeScreenAction.class).then(RedrawScreenAction.class))
                .put("KEY_REDRAW", Action.of(RedrawScreenAction.class))
                .put(" ",
                        Action.of(CheckpointAction.class)) /* Cmd.Checkpoint, TypeWhileSelected, SplitCurrentWord.
                 */.put("KEY_RETURN", Action.of(CheckpointAction.class)) /* Cmd.Checkpoint, TypeWhileSelected,
                        SplitCurrentParagraph. */.put("KEY_ESCAPE",
                        Action.of(ActivateMenuAction.class)) /* Cmd.ActivateMenu. */.put("KEY_MENU",
                        Action.of(ActivateMenuAction.class))
                .put("KEY_QUIT", Action.of(TerminateProgramAction.class))
                .build();

        /* Keep the welcome message and restart after reporting an internal error. */
        nonmodalMessage("Welcome to WordGrinder! Press ESC to show the menu.");
        for (; ; )
        {
            try
            {
                eventLoop(masterKeymap);
            }
            catch (Exception e)
            {
                StringWriter traceback = new StringWriter();
                e.printStackTrace(new PrintWriter(traceback));
                java.lang.System.out.print(traceback);
                modalMessage("Internal error!",
                        "Something went wrong inside WordGrinder! I'll try and " + "continue but you should save your work immediately (under a " + "different filename), exit, and send the following technical " + "information to the author:\n\n" + traceback);
            }
        }
    }
}
