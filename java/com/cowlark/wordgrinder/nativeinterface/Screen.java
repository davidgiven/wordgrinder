/* © 2026 David Given.
 * WordGrinder is licensed under the MIT open source licence. See COPYING.
 */

package com.cowlark.wordgrinder.nativeinterface;

import org.jspecify.annotations.NonNull;

/**
 * Backend-independent screen operations.
 */
public interface Screen
{
    /* Operations are supplied by an injected backend instance. */
    void screenInit(@NonNull String @NonNull [] args);

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

    void setColour(float @NonNull [] foreground, float @NonNull [] background);

    void dpyWriteUniChar(int x, int y, int character);

    void write(int x, int y, @NonNull String text);

    void clearArea(int x1, int y1, int x2, int y2);

    void gotoXY(int x, int y);

    void showCursor();

    void hideCursor();

    /**
     * Returns the current width and height in terminal cells.
     */
    int @NonNull [] getScreenSize();

    int getStringWidth(@NonNull String text);

    @NonNull String getBoundedString(@NonNull String text, int width);

    int getBytesOfCharacter(int firstByte);

    @NonNull MouseInputEvent decodeMouseEvent(int key);

    @NonNull InputEvent getEvent();

    /**
     * Reads input with a timeout in seconds; a negative timeout waits indefinitely.
     */
    @NonNull InputEvent getEvent(double timeout);

    boolean useUnicode();

    void setUnicode(boolean enabled);

    /* Input event values are independent of the native backend. */
    sealed interface InputEvent permits MouseInputEvent, KeyInputEvent
    {
    }

    record KeyInputEvent(@NonNull String key) implements InputEvent
    {
    }

    record MouseInputEvent(int x, int y, boolean b, boolean clicked) implements InputEvent
    {
    }
}
