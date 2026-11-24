package com.cowlark.wordgrinder.ui;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertSame;
import static org.junit.Assert.assertTrue;

import com.cowlark.wordgrinder.document.Word;
import com.cowlark.wordgrinder.eventbus.ChangedEvent;
import com.cowlark.wordgrinder.eventbus.EventBus;
import com.cowlark.wordgrinder.eventbus.RedrawEvent;
import com.cowlark.wordgrinder.nativeinterface.Display;
import com.cowlark.wordgrinder.nativeinterface.Screen.KeyInputEvent;
import com.cowlark.wordgrinder.utils.Injector;
import java.lang.reflect.Proxy;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import org.junit.Test;

public class MenuTreeTest
{
    /* An activation can open a submenu returned by an action. */
    @Test
    public void activatesInjectedTreeAndOpensReturnedSubmenu()
    {
        Fixture fixture = new Fixture();
        Menu child = new Menu("Child", List.of(
                Menu.Item.command("run", "R", "Run", null,
                        () -> new Action.ActionResult("child"))));
        VoidAction open = () -> new Action.ActionResult(child);
        Menu root = new Menu("Root", List.of(Menu.Item.command("open", "O", "Open", "O", open)));

        /* Visit the returned submenu, go back, then run its first command on the second visit. */
        fixture.keys("o", "KEY_LEFT", "o", "KEY_RETURN");
        fixture.activate(root);
        assertEquals(List.of("child"), fixture.messages);
        assertEquals(1, fixture.repaints);
        assertEquals(1, fixture.redraws);
        assertSame(open, fixture.tree.lookupAccelerator(root, fixture.settings, "KEY_O",
                fixture::repaint, fixture.messages::add));
    }

    /* Update both directions and preserve a deliberate unbinding across activations. */
    @Test
    public void changesDocumentAcceleratorsWithoutRestoringRemovedDefaults()
    {
        Fixture fixture = new Fixture();
        VoidAction action = () -> Action.ActionResult.SUCCEEDED;
        Menu root = new Menu("Root", List.of(Menu.Item.command("run", "R", "Run", "^R", action)));

        /* Bind a new key and verify the old key no longer resolves. */
        fixture.keys("KEY_^V", "KEY_^B", "KEY_ESCAPE");
        fixture.activate(root);
        assertEquals(Map.of("^B", "run"), fixture.settings.itemIdsByAccelerator);
        assertEquals(Map.of("run", "^B"), fixture.settings.acceleratorsByItemId);
        assertEquals(1, fixture.changes);
        assertSame(action, fixture.tree.lookupAccelerator(root, fixture.settings, "KEY_^B",
                fixture::repaint, fixture.messages::add));

        /* Remove the final binding and verify that neither key is active. */
        fixture.keys("KEY_^X", "KEY_ESCAPE");
        fixture.activate(root);
        assertTrue(fixture.settings.itemIdsByAccelerator.isEmpty());
        assertTrue(fixture.settings.acceleratorsByItemId.isEmpty());
        assertNull(fixture.tree.lookupAccelerator(root, fixture.settings, "KEY_^R",
                fixture::repaint, fixture.messages::add));
        assertEquals(2, fixture.redraws);
        assertEquals(2, fixture.changes);
    }

    /* Supply an in-memory display and observe the immediate and deferred redraw paths. */
    private static class Fixture
    {
        final TestScreen screen = new TestScreen();
        final EventBus bus = new EventBus();
        final MenuSettings settings = new MenuSettings();
        final List<String> messages = new ArrayList<>();
        final MenuTree tree;
        int repaints;
        int redraws;
        int changes;

        Fixture()
        {
            /* Inject the menu tree with the same collaborators its caller owns. */
            Injector injector = new Injector();
            Display display = (Display) Proxy.newProxyInstance(
                    Display.class.getClassLoader(), new Class<?>[]{Display.class},
                    (proxy, method, args) -> {
                        throw new AssertionError("Unexpected display call: " + method.getName());
                    });
            injector.bindInstance(Ui.class, new Ui(screen));
            injector.bindInstance(Word.class, new Word(display));
            injector.bindInstance(EventBus.class, bus);
            tree = injector.create(MenuTree.class);

            /* Record queued redraws and edits to accelerator bindings. */
            bus.addEventListener(RedrawEvent.class, event -> redraws++);
            bus.addEventListener(ChangedEvent.class, event -> changes++);
        }

        void keys(String... keys)
        {
            for (String key : keys)
                screen.events.add(new KeyInputEvent(key));
        }

        void activate(Menu menu)
        {
            tree.activate(menu, settings, this::repaint, messages::add);
        }

        void repaint()
        {
            repaints++;
        }
    }
}
