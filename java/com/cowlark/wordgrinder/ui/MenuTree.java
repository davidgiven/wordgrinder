package com.cowlark.wordgrinder.ui;

import com.cowlark.wordgrinder.document.Word;
import com.cowlark.wordgrinder.eventbus.ChangedEvent;
import com.cowlark.wordgrinder.eventbus.EventBus;
import com.cowlark.wordgrinder.eventbus.RedrawEvent;
import com.cowlark.wordgrinder.nativeinterface.Screen;
import com.cowlark.wordgrinder.nativeinterface.Screen.KeyInputEvent;
import com.cowlark.wordgrinder.nativeinterface.Screen.MouseInputEvent;
import com.cowlark.wordgrinder.ui.Action.ActionResult;
import com.cowlark.wordgrinder.ui.Menu.Item;
import com.cowlark.wordgrinder.utils.Injector.Inject;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.function.Consumer;
import org.jspecify.annotations.Nullable;

import static com.cowlark.wordgrinder.ui.Action.ActionResult.SUCCEEDED;
import static java.lang.Math.*;

/** Runs a caller-supplied menu hierarchy against a document set's accelerator bindings. */
public final class MenuTree
{
    /* Share the application's screen, renderer and event bus. */
    private final Ui ui;
    private final Screen screen;
    private final Word wordRenderer;
    private final EventBus eventBus;

    @Inject
    public MenuTree(Ui ui, Word wordRenderer, EventBus eventBus)
    {
        this.ui = ui;
        this.screen = ui.getScreen();
        this.wordRenderer = wordRenderer;
        this.eventBus = eventBus;
    }

    /**
     * Opens the supplied menu.
     * The redraw callback repaints the editor immediately behind an open menu,
     * including any status bar the caller wants to show.
     */
    public ActionResult activate(Menu root, MenuSettings settings,
            Runnable redraw, Consumer<String> message)
    {
        return activate(root, root, settings, redraw, message);
    }

    /* Keep the menu stack local to this activation. */
    private ActionResult activate(Menu root, Menu firstMenu, MenuSettings settings,
                                         Runnable redraw, Consumer<String> message)
    {
        initialiseBindings(root, settings);
        Session session = new Session(root, settings, redraw, message);
        try
        {
            session.run(firstMenu);
            return SUCCEEDED;
        }
        finally
        {
            screen.setNormal();
            eventBus.fireEvent(RedrawEvent.INSTANCE);
        }
    }

    /** Returns the action for an editor accelerator, or null if the key is unbound. */
    public @Nullable VoidAction lookupAccelerator(Menu root, MenuSettings settings, String key,
            Runnable redraw, Consumer<String> message)
    {
        /* Resolve the current menu contents so dynamic replacements are visible. */
        initialiseBindings(root, settings);
        String id = settings.itemIdsByAccelerator.get(acceleratorKey(key));
        if (id == null)
            return null;

        Item item = indexItems(root).get(id);
        if (item == null)
            return () -> new ActionResult("Menu item with ID " + id + " not found.");
        if (item.action() != null)
            return item.action();
        Menu submenu = item.submenu();
        if (submenu == null)
            return null;
        return () -> {
            activate(root, submenu, settings, redraw, message);
            return SUCCEEDED;
        };
    }

    /* Use the same key notation for native events and default bindings. */
    private static String acceleratorKey(String key)
    {
        String upper = key.toUpperCase(Locale.ROOT);
        return upper.startsWith("KEY_") ? upper.substring(4) : upper;
    }

    /* Install defaults once, preserving deliberate unbindings on later activations. */
    private static void initialiseBindings(Menu root, MenuSettings settings)
    {
        if (settings.initialised)
            return;
        if (settings.itemIdsByAccelerator.isEmpty() && settings.acceleratorsByItemId.isEmpty())
            installDefaults(root, settings);
        settings.initialised = true;
    }

    /* Rebuild both lookup directions from the menu definitions. */
    private static void installDefaults(Menu root, MenuSettings settings)
    {
        var items = indexItems(root);
        settings.itemIdsByAccelerator.clear();
        settings.acceleratorsByItemId.clear();
        for (Item item : items.values())
        {
            if (item.accelerator() != null)
                bind(settings, item.id(), acceleratorKey(item.accelerator()));
        }
    }

    /* Index current item IDs across the tree and visit shared submenus only once. */
    private static Map<String, Item> indexItems(Menu root)
    {
        Map<String, Item> items = new LinkedHashMap<>();
        indexItems(root, items, new HashSet<>());
        return items;
    }

    private static void indexItems(Menu menu, Map<String, Item> items, Set<Menu> visited)
    {
        if (!visited.add(menu))
            return;
        for (Item item : menu.items())
        {
            if (item.id() != null && items.putIfAbsent(item.id(), item) != null)
                throw new IllegalArgumentException("Duplicate menu ID " + item.id());
            if (item.submenu() != null)
                indexItems(item.submenu(), items, visited);
        }
    }

    /* Keep the forward and reverse settings in step when a shortcut changes. */
    private static void bind(MenuSettings settings, String id, String accelerator)
    {
        unbind(settings, id);
        String previous = settings.itemIdsByAccelerator.put(accelerator, id);
        if (previous != null)
            settings.acceleratorsByItemId.remove(previous);
        settings.acceleratorsByItemId.put(id, accelerator);
    }

    private static boolean unbind(MenuSettings settings, String id)
    {
        String accelerator = settings.acceleratorsByItemId.remove(id);
        return accelerator != null && settings.itemIdsByAccelerator.remove(accelerator, id);
    }

    /* Store the position and visible rows of each open menu independently. */
    private static final class Frame
    {
        final Menu menu;
        int selected;
        int top;
        int x;
        int y;
        int width;
        int rows;

        Frame(Menu menu)
        {
            this.menu = menu;
        }

        @Nullable Item selectedItem()
        {
            return selected < menu.items().size() ? menu.items().get(selected) : null;
        }
    }

    /* Run modal interaction with the supplied editor hooks and document settings. */
    private final class Session
    {
        final Menu root;
        final MenuSettings settings;
        final List<Frame> stack = new ArrayList<>();
        final Runnable redraw;
        final Consumer<String> message;

        Session(Menu root, MenuSettings settings,
                Runnable redraw, Consumer<String> message)
        {
            this.root = root;
            this.settings = settings;
            this.redraw = redraw;
            this.message = message;
        }

        void run(Menu firstMenu)
        {
            /* Keep the parent frames when descending and repaint them when ascending. */
            stack.add(new Frame(firstMenu));
            while (!stack.isEmpty() && !ui.isQuitting())
            {
                Frame frame = stack.getLast();
                draw(frame, stack.size() - 1);
                switch (screen.getEvent())
                {
                    case MouseInputEvent mouse -> handleMouse(frame, mouse);
                    case KeyInputEvent key -> handleKey(frame, key.key().toUpperCase(Locale.ROOT));
                }
            }
        }

        void handleKey(Frame frame, String key)
        {
            /* Handle modal and navigation keys before looking up an entry. */
            switch (key)
            {
                case "KEY_RESIZE" -> redrawStack();
                case "KEY_QUIT" -> ui.requestQuit();
                case "KEY_ESCAPE", "KEY_MENU", "KEY_^C" -> stack.clear();
                case "KEY_LEFT" -> back();
                case "KEY_UP" -> move(frame, -1);
                case "KEY_DOWN" -> move(frame, 1);
                case "KEY_PGUP" -> move(frame, -max(1, (frame.rows + 1) / 2));
                case "KEY_PGDN" -> move(frame, max(1, frame.rows / 2));
                case "KEY_SCROLLUP" -> scroll(frame, -1);
                case "KEY_SCROLLDOWN" -> scroll(frame, 1);
                case "KEY_RETURN", "KEY_RIGHT" -> select(frame.selectedItem());
                case "KEY_^X" -> removeBinding(frame);
                case "KEY_^V" -> replaceBinding(frame);
                case "KEY_^R" -> resetBindings();
                default -> select(frame.menu.lookupMenuKey(key));
            }
        }

        void handleMouse(Frame frame, MouseInputEvent mouse)
        {
            /* Clicks to the left or above move back. Clicks beyond the menu close it. */
            if (!mouse.b())
                return;
            if (mouse.x() < frame.x)
                back();
            else if (mouse.x() > frame.x + frame.width)
                stack.clear();
            else if (mouse.y() <= frame.y)
                back();
            else if (mouse.y() > frame.y + frame.rows)
                stack.clear();
            else
            {
                frame.selected = frame.top + mouse.y() - frame.y - 1;
                select(frame.selectedItem());
            }
        }

        void back()
        {
            stack.removeLast();
            if (!stack.isEmpty())
                redrawStack();
        }

        void move(Frame frame, int delta)
        {
            frame.selected = clamp(frame.selected + delta, 0,
                    max(0, frame.menu.items().size() - 1));
        }

        void scroll(Frame frame, int delta)
        {
            if (frame.rows == 0)
                return;
            frame.top = clamp(frame.top + delta, 0, frame.menu.items().size() - frame.rows);
            frame.selected = clamp(frame.selected, frame.top, frame.top + frame.rows - 1);
        }

        void select(@Nullable Item item)
        {
            /* Only commands and submenu entries consume a selection. */
            if (item == null || item.isSeparator())
                return;
            VoidAction action = item.action();
            Menu submenu = item.submenu();
            if (action != null)
                execute(action);
            else if (submenu != null)
                stack.add(new Frame(submenu));
        }

        void execute(VoidAction action)
        {
            /* A returned submenu keeps the stack open. Other results close the menus. */
            ActionResult result = action.execute();
            Menu submenu = result.menu();
            if (submenu != null)
                stack.add(new Frame(submenu));
            else
            {
                String text = result.message();
                if (text != null)
                    message.accept(text);
                stack.clear();
            }
        }

        void removeBinding(Frame frame)
        {
            Item item = frame.selectedItem();
            if (item != null && item.id() != null && unbind(settings, item.id()))
            {
                eventBus.fireEvent(new ChangedEvent());
                redrawStack();
            }
        }

        void replaceBinding(Frame frame)
        {
            /* Rebinding applies to the selected item and only accepts native special keys. */
            Item item = frame.selectedItem();
            if (item == null || item.id() == null)
                return;
            ui.drawStatusLine("Press new accelerator key for menu item.");
            if (screen.getEvent() instanceof KeyInputEvent input)
            {
                String key = input.key().toUpperCase(Locale.ROOT);
                if (key.equals("KEY_QUIT"))
                    ui.requestQuit();
                else if (key.startsWith("KEY_"))
                {
                    String accelerator = acceleratorKey(key);
                    if (accelerator.equals("ESCAPE") || accelerator.equals("RESIZE"))
                        message.accept("You can't bind that key.");
                    else if (settings.itemIdsByAccelerator.containsKey(accelerator))
                        message.accept("Sorry, " + accelerator + " is already bound elsewhere.");
                    else
                    {
                        bind(settings, item.id(), accelerator);
                        eventBus.fireEvent(new ChangedEvent());
                    }
                }
            }
            redrawStack();
        }

        void resetBindings()
        {
            /* Confirm before discarding document-specific bindings. */
            boolean confirmed = ui.newForm()
                    .setTitle("Reset menu keybindings?")
                    .setHeight(2)
                    .setStretchy(true)
                    .setRedraw(redraw)
                    .setHelpText("Y for yes, N for no, or ESCAPE to cancel")
                    .add(new WrappedLabelWidget(wordRenderer, eventBus)
                            .setBounds(1, 1, -1, -3)
                            .setValue("Are you sure you want to reset all the menu keybindings back to their defaults?"))
                    .on("y", Widget.Action.CONFIRM).on("Y", Widget.Action.CONFIRM)
                    .on("n", Widget.Action.CANCEL).on("N", Widget.Action.CANCEL)
                    .run();
            if (confirmed)
            {
                installDefaults(root, settings);
                eventBus.fireEvent(new ChangedEvent());
                message.accept("All keybindings have been reset to their default settings.");
                stack.clear();
            }
            else
                redrawStack();
        }

        void redrawStack()
        {
            /* Let the caller repaint the editor before restoring the menu overlays. */
            redraw.run();
            for (int i = 0; i < stack.size(); i++)
                draw(stack.get(i), i);
        }

        void draw(Frame frame, int depth)
        {
            /* Recalculate the visible area and keep keyboard selection in view. */
            int[] size = screen.getScreenSize();
            if (size[0] < 3 || size[1] < 3)
            {
                frame.rows = 0;
                return;
            }
            List<Item> items = frame.menu.items();
            frame.x = clamp(size[0] - 8, 0, depth * 4);
            frame.y = clamp(size[1] - 4, 0, depth * 2);
            frame.rows = min(items.size(), size[1] - frame.y - 3);
            move(frame, 0);
            if (frame.rows > 0)
                frame.top = clamp(frame.top, max(0, frame.selected - frame.rows + 1),
                        min(frame.selected, items.size() - frame.rows));

            /* Size the box for the labels and accelerator column within the screen. */
            int acceleratorWidth = 0;
            for (Item item : items)
            {
                String key = settings.acceleratorsByItemId.get(item.id());
                if (key != null)
                    acceleratorWidth = max(acceleratorWidth, screen.getStringWidth(key) + 1);
            }
            frame.width = min(size[0] - frame.x - 2,
                    frame.menu.maxWidth(screen) + 4 + acceleratorWidth);
            ui.setColour("ControlFG", "ControlBG");
            ui.drawTitledBox(frame.x, frame.y, frame.width, frame.rows, frame.menu.label());

            /* Draw the scroll indicator and each visible item. */
            if (frame.rows > 0 && frame.rows < items.size())
            {
                int start = frame.top * frame.rows / items.size();
                int end = (frame.top + frame.rows) * frame.rows / items.size();
                screen.setBright();
                for (int row = start; row <= min(end, frame.rows - 1); row++)
                    screen.write(frame.x + frame.width + 1, frame.y + row + 1,
                            screen.useUnicode() ? "║" : "#");
                screen.setNormal();
            }
            for (int row = 0; row < frame.rows; row++)
                drawItem(frame, items.get(frame.top + row), row, acceleratorWidth);
            screen.gotoXY(size[0] - 1, size[1] - 1);
            ui.drawStatusLine("^V rebinds a menu item; ^X unbinds it; ^R resets all bindings to default.");
        }

        void drawItem(Frame frame, Item item, int row, int acceleratorWidth)
        {
            /* Highlight the selected row and fit each column inside the border. */
            int y = frame.y + row + 1;
            if (frame.top + row == frame.selected)
            {
                screen.setReverse();
                screen.write(frame.x + 1, y, " ".repeat(frame.width));
            }
            if (item.isSeparator())
            {
                screen.setBright();
                screen.write(frame.x + 1, y, (screen.useUnicode() ? "─" : "-").repeat(frame.width));
            }
            else if (frame.width >= 4)
            {
                screen.write(frame.x + 4, y, screen.getBoundedString(item.label(),
                        max(0, frame.width - 3 - acceleratorWidth)));
                screen.setBold();
                screen.setBright();
                String key = settings.acceleratorsByItemId.get(item.id());
                if (key != null && screen.getStringWidth(key) < frame.width - 2)
                    screen.write(frame.x + frame.width - screen.getStringWidth(key), y, key);
                if (item.menuKey() != null)
                    screen.write(frame.x + 2, y, item.menuKey());
            }
            screen.setNormal();
        }
    }
}
