package com.cowlark.wordgrinder.forms;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertSame;
import static org.junit.Assert.assertTrue;

import com.cowlark.wordgrinder.nativeinterface.Screen.KeyInputEvent;
import com.cowlark.wordgrinder.nativeinterface.Screen.MouseInputEvent;
import org.junit.Test;
import java.util.List;

/**
 * Exercises drawing and timed input through an injected screen.
 */
public class UiTest
{
    /* Timeouts alternate cursor phases and truncate the final wait. */
    @Test
    public void blinkingHonoursTimeout()
    {
        TestScreen screen = new TestScreen();
        for (int i = 0; i < 3; i++)
            screen.events.add(new KeyInputEvent("KEY_TIMEOUT"));
        assertEquals(
                new KeyInputEvent("KEY_TIMEOUT"),
                new Ui(screen).getCharWithBlinkingCursor(1.5));
        assertEquals(3, screen.periods.size());
        assertEquals(0.8, screen.periods.get(0), 0.000001);
        assertEquals(0.53, screen.periods.get(1), 0.000001);
        assertEquals(0.17, screen.periods.get(2), 0.000001);
        assertEquals(List.of(true, false, true, false), screen.visibility);
    }

    /* Input received while hidden is returned unchanged and restores the cursor. */
    @Test
    public void blinkingReturnsInput()
    {
        TestScreen screen = new TestScreen();
        MouseInputEvent event = new MouseInputEvent(4, 5, true, true);
        screen.events.add(new KeyInputEvent("KEY_TIMEOUT"));
        screen.events.add(event);
        assertSame(event, new Ui(screen).getCharWithBlinkingCursor());
        assertEquals(List.of(true, false, true), screen.visibility);
    }

    /* Expired waits show the cursor without polling for input. */
    @Test
    public void expiredWaitDoesNotRead()
    {
        TestScreen screen = new TestScreen();
        assertEquals(new KeyInputEvent("KEY_TIMEOUT"), new Ui(screen).getCharWithBlinkingCursor(0));
        assertTrue(screen.periods.isEmpty());
        assertEquals(List.of(true), screen.visibility);
    }

    /* Text alignment measures clipped Unicode text in terminal cells. */
    @Test
    public void alignsAndClipsWideCharacters()
    {
        TestScreen screen = new TestScreen();
        Ui ui = new Ui(screen);
        ui.centreInField(10, 2, 5, "界a");
        ui.lAlignInField(10, 3, 2, "界a");
        ui.rAlignInField(10, 4, 5, "界a");
        assertEquals(List.of("11,2:界a", "10,3:界", "12,4:界a"), screen.writes);
    }

    /* Box coordinates retain the Lua interior dimensions and outside padding. */
    @Test
    public void drawsBoxAndCaptions()
    {
        TestScreen screen = new TestScreen();
        new Ui(screen).drawTitledBox(10, 2, 4, 1, "Hi", "Bye");
        assertEquals(
                List.of(
                        "9,2: ┌",
                        "15,2:┐ ",
                        "9,4: └",
                        "15,4:┘ ",
                        "11,2:────",
                        "11,4:────",
                        "9,3: │",
                        "15,3:│ ",
                        "11,3:    ",
                        "12,2:Hi",
                        "11,4:Bye"), screen.writes);
    }

    /* The same drawing helper supports the ASCII character set. */
    @Test
    public void drawsAsciiBox()
    {
        TestScreen screen = new TestScreen()
        {
            @Override
            public boolean useUnicode()
            {
                return false;
            }
        };
        new Ui(screen).drawBox(0, 0, 1, 0);
        assertEquals(
                List.of("-1,0: +", "2,0:+ ", "-1,1: +", "2,1:+ ", "1,0:-", "1,1:-"),
                screen.writes);
    }
}
