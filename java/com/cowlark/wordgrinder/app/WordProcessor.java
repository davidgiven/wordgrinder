package com.cowlark.wordgrinder.app;

import com.cowlark.wordgrinder.addons.undo.CheckpointAction;
import com.cowlark.wordgrinder.document.Word;
import com.cowlark.wordgrinder.eventbus.*;
import com.cowlark.wordgrinder.nativeinterface.Screen;
import com.cowlark.wordgrinder.nativeinterface.Screen.InputEvent;
import com.cowlark.wordgrinder.nativeinterface.Screen.KeyInputEvent;
import com.cowlark.wordgrinder.nativeinterface.Screen.MouseInputEvent;
import com.cowlark.wordgrinder.ui.*;
import com.cowlark.wordgrinder.utils.Injector;
import com.cowlark.wordgrinder.utils.Injector.Inject;
import com.google.common.collect.ImmutableMap;

import java.io.PrintWriter;
import java.io.StringWriter;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import static com.cowlark.wordgrinder.ui.Action.ActionResult.SUCCEEDED;

/**
 * The word-processor input loop, translated from main.lua.
 */
public class WordProcessor
{
    private final Injector injector;
    private final Ui ui;
    private final Screen screen;
    private final Word wordRenderer;
    private final Navigation navigation;
    private final MenuTree menuTree;

    /* Keep menu preferences across activations until an active document set supplies them. */
    private final MenuSettings menuSettings = new MenuSettings();
    private final EventBus eventBus;
    private static final double IDLE_TIME = (Ui.BLINK_ON_TIME + Ui.BLINK_OFF_TIME) * 5;

    private final List<String> messages = new ArrayList<>();

    /* Mouse selection tracks the initial press across subsequent drag and release events. */
    private boolean oldMouseButton;
    private int oldMouseX;
    private int oldMouseY;

    /* Share the application injector with the action dispatcher. */
    @Inject
    public WordProcessor(Injector injector, Ui ui, Screen screen, Word wordRenderer, EventBus eventBus, Navigation navigation, MenuTree menuTree)
    {
        this.injector = injector;
        this.ui = ui;
        this.screen = screen;
        this.wordRenderer = wordRenderer;
        this.eventBus = eventBus;
        this.navigation = navigation;
        this.menuTree = menuTree;
    }

    /**
     * Adds a transient message and schedules its display.
     */
    public void nonmodalMessage(String text)
    {
        messages.add(text);
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

    /* Draw the available desktop and messages; document and status-bar rendering are pending. */
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
            ui.setColour(null, "Desktop");
            screen.clearScreen();

            /* Stack messages upwards from the bottom, with the newest message last on screen. */
            int[] size = screen.getScreenSize();
            int y = size[1] - 1;
            if (!wordProcessor.messages.isEmpty())
            {
                ui.setColour("MessageFG", "MessageBG");
                screen.setReverse();
                for (int i = wordProcessor.messages.size() - 1; i >= 0 && y >= 0; i--, y--)
                {
                    screen.clearArea(0, y, size[0] - 1, y);
                    screen.write(0, y, wordProcessor.messages.get(i));
                }
                screen.setNormal();
            }

            return SUCCEEDED;
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
                Action.of(GotoXYPositionAction.class).execute(mouse.x(), mouse.y());
                /* TODO: Cmd.UnsetMark(), Cmd.GotoXYPosition(x, y), Cmd.SetMark(). */
            }
            else
            {

                Action.of(GotoXYPositionAction.class).execute(mouse.x(), mouse.y());
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
                .add(new WrappedLabelWidget(wordRenderer, eventBus).setBounds(1, 1, -1, -3).setValue(text))
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
                    wordProcessor.menuSettings,
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
