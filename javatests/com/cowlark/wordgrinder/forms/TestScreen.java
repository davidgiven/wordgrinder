package com.cowlark.wordgrinder.forms;

import com.cowlark.wordgrinder.nativeinterface.Colour;
import com.cowlark.wordgrinder.nativeinterface.Screen;
import org.jspecify.annotations.NonNull;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.List;
import java.util.Queue;

/**
 * Records screen operations without linking to a native backend.
 */
class TestScreen implements Screen
{
    /* Supply deterministic input and retain observable output. */
    final Queue<InputEvent> events = new ArrayDeque<>();
    final List<Double> periods = new ArrayList<>();
    final List<Boolean> visibility = new ArrayList<>();
    final List<String> writes = new ArrayList<>();
    Colour foreground;
    Colour background;

    /* Implement the screen contract and reject unexpected operations. */
    @Override
    public void screenInit(@NonNull String @NonNull [] args)
    {
        throw new AssertionError("Unexpected screen operation: screenInit");
    }

    @Override
    public void initScreen()
    {
        throw new AssertionError("Unexpected screen operation: initScreen");
    }

    @Override
    public void screenDeinit()
    {
        throw new AssertionError("Unexpected screen operation: screenDeinit");
    }

    @Override
    public void deinitScreen()
    {
        throw new AssertionError("Unexpected screen operation: deinitScreen");
    }

    @Override
    public void clearScreen()
    {
        throw new AssertionError("Unexpected screen operation: clearScreen");
    }

    @Override
    public void sync()
    {

    }

    @Override
    public void setBold()
    {

    }

    @Override
    public void setUnderline()
    {
        throw new AssertionError("Unexpected screen operation: setUnderline");
    }

    @Override
    public void setReverse()
    {

    }

    @Override
    public void setBright()
    {

    }

    @Override
    public void setDim()
    {
        throw new AssertionError("Unexpected screen operation: setDim");
    }

    @Override
    public void setItalic()
    {
        throw new AssertionError("Unexpected screen operation: setItalic");
    }

    @Override
    public void setNormal()
    {

    }

    @Override
    public void setColour(@NonNull Colour foreground, @NonNull Colour background)
    {
        this.foreground = foreground;
        this.background = background;
    }

    @Override
    public void dpyWriteUniChar(int x, int y, int character)
    {
        throw new AssertionError("Unexpected screen operation: dpyWriteUniChar");
    }

    @Override
    public void write(int x, int y, @NonNull String text)
    {
        writes.add(x + "," + y + ":" + text);
    }

    @Override
    public void clearArea(int x1, int y1, int x2, int y2)
    {

    }

    @Override
    public void gotoXY(int x, int y)
    {

    }

    @Override
    public void showCursor()
    {
        visibility.add(true);
    }

    @Override
    public void hideCursor()
    {
        visibility.add(false);
    }

    @Override
    public int @NonNull [] getScreenSize()
    {
        return new int[]{80, 24};
    }

    @Override
    public int getStringWidth(@NonNull String text)
    {
        int width = 0;
        for (int cp : text.codePoints().toArray())
            width += cp == 0x1f600 || cp == '界' ? 2 : 1;
        return width;
    }

    @Override
    public @NonNull String getBoundedString(@NonNull String text, int width)
    {
        int end = 0;
        while (end < text.length())
        {
            int next = text.offsetByCodePoints(end, 1);
            if (getStringWidth(text.substring(0, next)) > width)
                break;
            end = next;
        }
        return text.substring(0, end);
    }

    @Override
    public int getBytesOfCharacter(int firstByte)
    {
        throw new AssertionError("Unexpected screen operation: getBytesOfCharacter");
    }

    @Override
    public @NonNull MouseInputEvent decodeMouseEvent(int key)
    {
        throw new AssertionError("Unexpected screen operation: decodeMouseEvent");
    }

    @Override
    public @NonNull InputEvent getEvent()
    {
        return events.remove();
    }

    @Override
    public @NonNull InputEvent getEvent(double timeout)
    {
        periods.add(timeout);
        return events.remove();
    }

    @Override
    public boolean useUnicode()
    {
        return true;
    }

    @Override
    public void setUnicode(boolean enabled)
    {
        throw new AssertionError("Unexpected screen operation: setUnicode");
    }
}
