/* © 2026 David Given.
 * WordGrinder is licensed under the MIT open source licence. See COPYING.
 */

package com.cowlark.wordgrinder.nativeinterface;


/**
 * Backend-independent screen operations.
 */
public interface Screen
{
    /* Operations are supplied by an injected backend instance. */
    void screenInit(String[] args);

    void initScreen();

    void screenDeinit();

    void deinitScreen();

    void clearScreen();

    void sync();

    void setBold();

    void setUnderline();

    void setReverse();

    void setBright();

    void setDim();

    void setItalic();

    void setNormal();

    void setColour(Colour foreground, Colour background);

    void dpyWriteUniChar(int x, int y, int character);

    void write(int x, int y, String text);

    void clearArea(int x1, int y1, int x2, int y2);

    void gotoXY(int x, int y);

    void showCursor();

    void hideCursor();

    /**
     * Returns the current width and height in terminal cells.
     */
    int[] getScreenSize();

    int getStringWidth(String text);

    String getBoundedString(String text, int width);

    int getBytesOfCharacter(int firstByte);

    MouseInputEvent decodeMouseEvent(int key);

    InputEvent getEvent();

    /**
     * Reads input with a timeout in seconds; a negative timeout waits indefinitely.
     */
    InputEvent getEvent(double timeout);

    boolean useUnicode();

    void setUnicode(boolean enabled);

    /* Input event values are independent of the native backend. */
    sealed interface InputEvent permits MouseInputEvent, KeyInputEvent
    {
    }

    record KeyInputEvent(String key) implements InputEvent
    {
    }

    record MouseInputEvent(int x, int y, boolean b, boolean clicked) implements InputEvent
    {
    }
}
