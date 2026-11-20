package com.cowlark.wordgrinder.ui;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;
import static org.junit.Assert.fail;

import com.cowlark.wordgrinder.nativeinterface.Screen;
import org.jspecify.annotations.NonNull;
import org.junit.Test;
import java.util.List;

/**
 * Exercises widget state transitions without requiring the native screen backend.
 */
public class WidgetTest
{
    /* Dispatch through the public binding map just as a form runner would. */
    private static Widget.@NonNull Action press(@NonNull Widget<?> widget, @NonNull String key)
    {
        return widget.keybindings.get(key).apply(key);
    }

    /* Navigation and deletion must never split a supplementary code point. */
    @Test
    public void editsSupplementaryCharacters()
    {
        Field field = new Field();
        field.value = "a😀b";
        field.init();
        press(field, "KEY_LEFT");
        assertEquals(3, field.cursor);
        press(field, "KEY_LEFT");
        assertEquals(1, field.cursor);
        press(field, "KEY_RIGHT");
        assertEquals(3, field.cursor);
        press(field, "KEY_BACKSPACE");
        assertEquals("ab", field.value);
        assertEquals(1, field.cursor);
        field.key(new Screen.KeyInputEvent("😀"));
        assertEquals("a😀b", field.value);
        assertEquals(3, field.cursor);
        press(field, "KEY_LEFT");
        press(field, "KEY_DELETE");
        assertEquals("ab", field.value);
        assertEquals(1, field.cursor);
        assertEquals(3, field.changes);
    }

    /* Editing replaces transient text, whereas navigation keeps it. */
    @Test
    public void handlesTransientTextAndSymbolicKeys()
    {
        Field field = new Field();
        field.value = "initial";
        field.transientValue = true;
        field.init();
        field.init();
        assertEquals(7, field.cursor);
        field.key(new Screen.KeyInputEvent("KEY_UNKNOWN"));
        assertTrue(field.transientValue);
        field.key(new Screen.KeyInputEvent("😀"));
        assertEquals("😀", field.value);
        assertEquals(2, field.cursor);
        assertFalse(field.transientValue);
        field.transientValue = true;
        press(field, "KEY_HOME");
        assertFalse(field.transientValue);
        assertEquals("😀", field.value);
        press(field, "KEY_END");
        assertEquals(2, field.cursor);
        press(field, "KEY_^U");
        assertEquals("", field.value);
        assertEquals(0, field.offset);
        assertEquals(0, field.cursor);
        assertEquals(2, field.changes);
    }

    /* Each checkbox owns its bindings and emits a change on space. */
    @Test
    public void checkboxBindingsBelongToTheirInstance()
    {
        class Checkbox extends CheckboxWidget
        {
            int changes;

            @Override
            public void draw()
            {
            }

            @Override
            public @NonNull Action changed()
            {
                changes++;
                return Action.NOP;
            }
        }
        Checkbox first = new Checkbox();
        Checkbox second = new Checkbox();
        assertEquals(Widget.Action.NOP, press(first, " "));
        assertTrue(first.value);
        assertFalse(second.value);
        assertEquals(1, first.changes);
        press(first, " ");
        assertFalse(first.value);
    }

    /* Toggle arrows stop at the ends, while space wraps around. */
    @Test
    public void toggleStopsAndCycles()
    {
        ToggleWidget toggle = new ToggleWidget()
        {
            @Override
            public void draw()
            {
            }
        };
        toggle.values = List.of("one", "two");
        press(toggle, "KEY_LEFT");
        assertEquals(0, toggle.value);
        press(toggle, "KEY_RIGHT");
        press(toggle, "KEY_RIGHT");
        assertEquals(1, toggle.value);
        press(toggle, " ");
        assertEquals(0, toggle.value);
    }

    /* Browser navigation propagates the change hook's command and clamps pages. */
    @Test
    public void browserNavigatesAndKeepsSelectionVisible()
    {
        class Browser extends BrowserWidget
        {
            int changes;

            @Override
            public void draw()
            {
                adjustOffset();
            }

            @Override
            public @NonNull Action changed()
            {
                changes++;
                return Action.CONFIRM;
            }
        }
        Browser browser = new Browser();
        browser.realheight = 4;
        for (int i = 0; i < 10; i++)
            browser.data.add(new BrowserWidget.Item("" + i, "item", null));
        assertEquals(Widget.Action.NOP, press(browser, "KEY_UP"));
        assertEquals(Widget.Action.CONFIRM, press(browser, "KEY_DOWN"));
        assertEquals(1, browser.cursor);
        assertEquals(0, browser.offset);
        press(browser, "KEY_PGDN");
        assertEquals(3, browser.cursor);
        assertEquals(1, browser.offset);
        for (int i = 0; i < 10; i++)
            press(browser, "KEY_PGDN");
        assertEquals(9, browser.cursor);
        assertEquals(7, browser.offset);
        int changes = browser.changes;
        assertEquals(Widget.Action.NOP, press(browser, "KEY_DOWN"));
        assertEquals(changes, browser.changes);
        press(browser, "KEY_PGUP");
        assertEquals(7, browser.cursor);
    }

    /* Empty lists remain stable under every navigation binding. */
    @Test
    public void browserAcceptsEmptyData()
    {
        BrowserWidget browser = new BrowserWidget()
        {
            @Override
            public void draw()
            {
                fail("Empty navigation must not redraw");
            }
        };
        browser.realheight = 6;
        for (String key : List.of("KEY_UP", "KEY_DOWN", "KEY_PGUP", "KEY_PGDN"))
            assertEquals(Widget.Action.NOP, press(browser, key));
        assertEquals(0, browser.cursor);
    }

    /* Replace native drawing with observations of change notifications. */
    private static class Field extends TextFieldWidget
    {
        int changes;

        @Override
        public void draw()
        {
        }

        @Override
        public @NonNull Action changed()
        {
            changes++;
            return Action.NOP;
        }
    }
}
