package com.cowlark.wordgrinder.ui;

import com.cowlark.wordgrinder.nativeinterface.Colour;

import com.cowlark.wordgrinder.ui.Widget.Action;
import com.cowlark.wordgrinder.nativeinterface.Screen.KeyInputEvent;
import com.cowlark.wordgrinder.nativeinterface.Screen.MouseInputEvent;
import java.util.ArrayList;
import java.util.List;
import org.jspecify.annotations.NonNull;
import org.junit.Test;
import static org.junit.Assert.*;

/** Exercises modal form layout and input dispatch through an injected screen. */
public class FormTest
{
    /* Observe layout, focus and generic keyboard delivery without native drawing. */
    private static class Probe extends Widget<Probe>
    {
        int initialisations;
        int draws;
        final List<String> keys = new ArrayList<>();
        final List<Boolean> focusHistory = new ArrayList<>();
        final List<Integer> widths = new ArrayList<>();

        Probe(boolean focusable)
        {
            setFocusable(focusable).setBounds(1, 1, -1, -1);
        }

        @Override public void init() { initialisations++; }
        @Override public void draw()
        {
            draws++;
            focusHistory.add(focus);
            widths.add(realwidth);
        }
        @Override public @NonNull Action key(@NonNull KeyInputEvent event)
        {
            keys.add(event.key());
            return Action.NOP;
        }
    }

    /* Builder configuration controls fixed geometry, captions, backdrop and colours. */
    @Test
    public void buildsAndConfirmsForm()
    {
        TestScreen screen = new TestScreen();
        Ui ui = new Ui(screen);
        ui.setTheme("Classic");
        Probe widget = new Probe(true);
        int[] backdrop = {0};
        screen.events.add(new KeyInputEvent("KEY_RETURN"));
        Form form = new Form(ui).setTitle("Example").setSize(20, 6).setHelpText("Help")
                .setRedraw(() -> { assertEquals(1, widget.initialisations); backdrop[0]++; })
                .add(widget).on("KEY_RETURN", Action.CONFIRM);
        assertTrue(form.run());
        assertEquals(1, backdrop[0]);
        assertEquals(1, widget.draws);
        assertTrue(widget.focus);
        assertEquals(31, widget.realx1);
        assertEquals(10, widget.realy1);
        assertEquals(49, widget.realx2);
        assertEquals(14, widget.realy2);
        assertEquals(18, widget.realwidth);
        assertEquals(4, widget.realheight);
        assertTrue(screen.writes.contains("36,8:Example"));
        assertTrue(screen.writes.contains("37,15:<Help>"));
        assertEquals(new Colour(1, 1, 1), screen.foreground);
        assertEquals(new Colour(0, 0, 0), screen.background);
    }

    /* Large dimensions and negative widget bounds must be recalculated on resize. */
    @Test
    public void resizesLargeForms()
    {
        TestScreen screen = new TestScreen()
        {
            int queries;
            @Override public int @NonNull [] getScreenSize()
            {
                return ++queries == 1 ? new int[] {80, 24} : new int[] {100, 30};
            }
        };
        Probe widget = new Probe(true);
        screen.events.add(new KeyInputEvent("KEY_RESIZE"));
        screen.events.add(new KeyInputEvent("KEY_ESCAPE"));
        assertFalse(new Form(new Ui(screen)).add(widget).run());
        assertEquals(List.of(66, 83), widget.widths);
        assertEquals(8, widget.realx1);
        assertEquals(3, widget.realy1);
        assertEquals(91, widget.realx2);
        assertEquals(26, widget.realy2);
        assertEquals(2, widget.initialisations);
    }

    /* Stretchy layout measures only the first flexible widget and does not accumulate height. */
    @Test
    public void calculatesStretchyHeightOnEveryRedraw()
    {
        TestScreen screen = new TestScreen();
        List<Integer> measuredWidths = new ArrayList<>();
        Probe widget = new Probe(false)
        {
            @Override public int calculateHeight()
            {
                measuredWidths.add(realwidth);
                return 3;
            }
        };
        Probe second = new Probe(false)
        {
            @Override public int calculateHeight() { fail("Only the first flexible widget is measured"); return 0; }
        };
        screen.events.add(new KeyInputEvent("r"));
        screen.events.add(new KeyInputEvent("KEY_RETURN"));
        assertTrue(new Form(new Ui(screen)).setSize(20, 2).setStretchy(true).add(widget).add(second)
                .on("r", Action.REDRAW).on("KEY_RETURN", Action.CONFIRM).run());
        assertEquals(List.of(18, 18), measuredWidths);
        assertEquals(10, widget.realy1);
        assertEquals(13, widget.realy2);
        assertEquals(3, widget.realheight);
        assertTrue(screen.periods.isEmpty());
    }

    /* Widget bindings win over form bindings; form bindings win over navigation and generic keys. */
    @Test
    public void preservesKeyboardDispatchPrecedence()
    {
        TestScreen screen = new TestScreen();
        Probe first = new Probe(true);
        Probe second = new Probe(true);
        List<String> bindings = new ArrayList<>();
        first.keybindings.put("KEY_UP", key -> { bindings.add("widget"); return Action.NOP; });
        for (String key : List.of("KEY_UP", "KEY_DOWN", "x", "KEY_RETURN"))
            screen.events.add(new KeyInputEvent(key));
        assertTrue(new Form(new Ui(screen)).setSize(20, 6).add(first).add(second)
                .on("KEY_UP", (form, key) -> { fail("The widget binding must win"); return Action.NOP; })
                .on("KEY_DOWN", (form, key) -> { bindings.add("form"); return Action.NOP; })
                .on("KEY_RETURN", Action.CONFIRM).run());
        assertEquals(List.of("widget", "form"), bindings);
        assertEquals(List.of("x"), first.keys);
        assertTrue(first.focus);
        assertFalse(second.focus);
    }

    /* Default navigation wraps, skips passive widgets and updates focus on redraw. */
    @Test
    public void cyclesFocusInBothDirections()
    {
        TestScreen screen = new TestScreen();
        Probe first = new Probe(true);
        Probe passive = new Probe(false);
        Probe last = new Probe(true);
        for (String key : List.of("KEY_UP", "KEY_DOWN", "KEY_DOWN", "KEY_RETURN"))
            screen.events.add(new KeyInputEvent(key));
        assertTrue(new Form(new Ui(screen)).setSize(20, 6).add(first).add(passive).add(last)
                .on("KEY_RETURN", Action.CONFIRM).run());
        assertEquals(List.of(true, false, true, false), first.focusHistory);
        assertEquals(List.of(false, true, false, true), last.focusHistory);
        assertEquals(List.of(false, false, false, false), passive.focusHistory);
    }

    /* A lone focused widget must not hang when navigation cannot move elsewhere. */
    @Test
    public void singleWidgetNavigationIsStable()
    {
        TestScreen screen = new TestScreen();
        Probe widget = new Probe(true);
        for (String key : List.of("KEY_UP", "KEY_DOWN", "KEY_ESCAPE"))
            screen.events.add(new KeyInputEvent(key));
        assertFalse(new Form(new Ui(screen)).add(widget).run());
        assertEquals(1, widget.draws);
    }

    /* Escape and Ctrl+C cancel before form bindings; explicit widget bindings may override them. */
    @Test
    public void cancellationRespectsWidgetOverrides()
    {
        for (String key : List.of("KEY_ESCAPE", "KEY_^C"))
        {
            TestScreen screen = new TestScreen();
            screen.events.add(new KeyInputEvent(key));
            assertFalse(new Form(new Ui(screen)).on(key, Action.CONFIRM).run());
            Probe widget = new Probe(true);
            widget.keybindings.put(key, ignored -> Action.CONFIRM);
            screen.events.add(new KeyInputEvent(key));
            assertTrue(new Form(new Ui(screen)).add(widget).run());
        }
    }

    /* Mouse hits include the lower and right bounds and redraw when focus transfers. */
    @Test
    public void mouseClickTransfersFocus()
    {
        TestScreen screen = new TestScreen();
        Probe first = new Probe(true);
        first.x2 = 3;
        first.y2 = 2;
        Probe second = new Probe(true);
        second.x1 = 5;
        second.x2 = 8;
        second.y2 = 2;
        screen.events.add(new MouseInputEvent(38, 11, true, true));
        screen.events.add(new KeyInputEvent("KEY_RETURN"));
        assertTrue(new Form(new Ui(screen)).setSize(20, 6).add(first).add(second)
                .on("KEY_RETURN", Action.CONFIRM).run());
        assertEquals(List.of(true, false), first.focusHistory);
        assertEquals(List.of(false, true), second.focusHistory);
    }

    /* Non-button events reach the mouse hook without changing the current focus. */
    @Test
    public void mouseHookCanConfirmWithoutFocus()
    {
        TestScreen screen = new TestScreen();
        Probe widget = new Probe(false)
        {
            @Override public @NonNull Action mouse(@NonNull MouseInputEvent event)
            {
                assertFalse(event.b());
                assertFalse(focus);
                return Action.CONFIRM;
            }
        };
        screen.events.add(new MouseInputEvent(32, 10, false, false));
        assertTrue(new Form(new Ui(screen)).setSize(20, 6).add(widget).run());
        assertTrue(screen.periods.isEmpty());
    }

    /* Transient display invalidation redraws before the next event is dispatched. */
    @Test
    public void invalidatedFormsRedrawBeforeDispatch()
    {
        TestScreen screen = new TestScreen();
        Probe widget = new Probe(true);
        for (String key : List.of("overlay", "check"))
            screen.events.add(new KeyInputEvent(key));
        assertTrue(new Form(new Ui(screen)).add(widget)
                .on("overlay", (form, key) -> { form.invalidate(); return Action.NOP; })
                .on("check", (form, key) -> { assertEquals(2, widget.draws); return Action.CONFIRM; })
                .run());
    }

    /* Real widgets receive editing and toggle keys while unbound arrows move form focus. */
    @Test
    public void runsTextFieldAndCheckboxTogether()
    {
        TestScreen screen = new TestScreen();
        TextFieldWidget field = new TextFieldWidget().setBounds(1, 1, -1, 2);
        CheckboxWidget checkbox = new CheckboxWidget().setBounds(1, 3, -1, 4);
        for (String key : List.of("😀", "KEY_DOWN", " ", "KEY_UP", "KEY_HOME", "A", "KEY_RETURN"))
            screen.events.add(new KeyInputEvent(key));
        assertTrue(new Form(new Ui(screen)).setTitle("Edit").setSize(30, 6).add(field).add(checkbox)
                .on("KEY_RETURN", Action.CONFIRM).run());
        assertEquals("A😀", field.value);
        assertEquals(1, field.cursor);
        assertTrue(checkbox.value);
        assertTrue(field.focus);
        assertFalse(checkbox.focus);
    }

    /* Fluent base and concrete setters compose before Form.add supplies the shared screen. */
    @Test
    public void fluentlyConfiguredWidgetsShareTheFormScreen()
    {
        TestScreen screen = new TestScreen();
        LabelWidget label = new LabelWidget().setBounds(1, 1, -1, 2)
                .setFocusable(false).setAlign(LabelWidget.Alignment.LEFT).setValue("Fluent");
        DividerWidget divider = new DividerWidget().setBounds(1, 3, -1, 3);
        CheckboxWidget checkbox = new CheckboxWidget().setBounds(1, 4, -1, 5)
                .setLabel("Check").setValue(false);
        ToggleWidget toggle = new ToggleWidget().setX1(1).setY1(6).setX2(-1).setY2(7)
                .setValues(List.of("First", "Second")).setLabel("Mode").setValue(0);
        TextFieldWidget field = new TextFieldWidget().setBounds(1, 8, -1, 9)
                .setValue("Initial").setCursor(-1).setOffset(0).setTransientValue(true);
        BrowserWidget browser = new BrowserWidget().setBounds(1, 10, -1, 13)
                .setLabel("Items").setData(List.of(
                        new BrowserWidget.Item("a", "First item", null),
                        new BrowserWidget.Item("b", "Second item", null)))
                .setCursor(0).setOffset(-1);
        for (String key : List.of(" ", "KEY_DOWN", "KEY_RIGHT", "KEY_DOWN", "x",
                "KEY_DOWN", "KEY_DOWN", "KEY_RETURN"))
            screen.events.add(new KeyInputEvent(key));
        assertTrue(new Form(new Ui(screen)).setSize(40, 14)
                .add(label).add(divider).add(checkbox).add(toggle).add(field).add(browser)
                .on("KEY_RETURN", Action.CONFIRM).run());
        assertTrue(screen.writes.contains("21,6:Fluent"));
        assertTrue(screen.writes.contains("21,8:" + "─".repeat(38)));
        assertTrue(checkbox.value);
        assertEquals(1, toggle.value);
        assertEquals("x", field.value);
        assertFalse(field.transientValue);
        assertEquals(1, browser.cursor);
        assertTrue(browser.focus);
    }

    /* Explicit focus is honoured, and a system quit is shared by all forms on the UI. */
    @Test
    public void quitStateIsSharedAndCanBeCancelled()
    {
        TestScreen screen = new TestScreen();
        Ui ui = new Ui(screen);
        Probe first = new Probe(true);
        Probe second = new Probe(true);
        screen.events.add(new KeyInputEvent("KEY_QUIT"));
        assertFalse(new Form(ui).add(first).add(second).setFocus(second)
                .on("KEY_QUIT", Action.CONFIRM).run());
        assertFalse(first.focus);
        assertTrue(second.focus);
        assertTrue(ui.isQuitting());
        assertFalse(new Form(ui).run());
        ui.cancelQuit();
        screen.events.add(new KeyInputEvent("yes"));
        assertTrue(new Form(ui).on("yes", Action.CONFIRM).run());
    }
}
