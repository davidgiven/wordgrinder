package com.cowlark.wordgrinder;

import org.teavm.interop.Address;
import org.teavm.interop.Import;
import org.teavm.interop.Structure;
import org.teavm.interop.Strings;
import org.teavm.interop.c.Include;
import org.teavm.interop.c.Name;
import org.teavm.interop.c.Native;
import org.teavm.interop.c.Variable;

/**
 * Direct bindings for TeaVM's C backend. Link the generated code with ncurses.
 * Coordinates are (y, x); functions return OK or ERR unless documented by ncurses.
 * String arguments are converted to NUL-terminated bytes in the current C locale
 * and freed after each call. Embedded NUL characters terminate the native string.
 * Length limits for addnstr/waddnstr count encoded bytes, not Java characters.
 * These methods cannot be called on a regular JVM.
 */
@Include(value = "curses.h", isSystem = true)
public final class NCurses
{
    private NCurses() {}

    /** Opaque WINDOW pointer. Obtain from initscr/newwin; release newwin windows with delwin. */
    @Include(value = "curses.h", isSystem = true)
    @Native
    @Name("WINDOW")
    public static class Window extends Structure
    {
        private Window() {}
    }

    @Include(value = "stdlib.h", isSystem = true)
    @Import(name = "free")
    private static native void free(Address pointer);

    // Screen and terminal modes.
    @Import(name = "initscr")
    public static native Window initscr();

    @Import(name = "endwin")
    public static native int endwin();

    @Import(name = "isendwin")
    public static native boolean isendwin();

    @Import(name = "cbreak")
    public static native int cbreak();

    @Import(name = "nocbreak")
    public static native int nocbreak();

    @Import(name = "raw")
    public static native int raw();

    @Import(name = "noraw")
    public static native int noraw();

    @Import(name = "echo")
    public static native int echo();

    @Import(name = "noecho")
    public static native int noecho();

    @Import(name = "nl")
    public static native int nl();

    @Import(name = "nonl")
    public static native int nonl();

    @Import(name = "curs_set")
    public static native int curs_set(int visibility);

    @Import(name = "beep")
    public static native int beep();

    @Import(name = "flash")
    public static native int flash();

    @Import(name = "napms")
    public static native int napms(int milliseconds);


    // Windows and input.
    @Import(name = "newwin")
    public static native Window newwin(int lines, int columns, int y, int x);

    @Import(name = "subwin")
    public static native Window subwin(Window parent, int lines, int columns, int y, int x);

    @Import(name = "derwin")
    public static native Window derwin(Window parent, int lines, int columns, int y, int x);

    @Import(name = "delwin")
    public static native int delwin(Window window);

    @Import(name = "mvwin")
    public static native int mvwin(Window window, int y, int x);

    @Import(name = "keypad")
    public static native int keypad(Window window, boolean enabled);

    @Import(name = "nodelay")
    public static native int nodelay(Window window, boolean enabled);

    @Import(name = "notimeout")
    public static native int notimeout(Window window, boolean enabled);

    @Import(name = "timeout")
    public static native void timeout(int milliseconds);

    @Import(name = "wtimeout")
    public static native void wtimeout(Window window, int milliseconds);

    @Import(name = "getch")
    public static native int getch();

    @Import(name = "wgetch")
    public static native int wgetch(Window window);

    @Import(name = "ungetch")
    public static native int ungetch(int key);

    @Import(name = "flushinp")
    public static native int flushinp();


    // Drawing and refreshing.
    @Import(name = "refresh")
    public static native int refresh();

    @Import(name = "erase")
    public static native int erase();

    @Import(name = "clear")
    public static native int clear();

    @Import(name = "clrtobot")
    public static native int clrtobot();

    @Import(name = "clrtoeol")
    public static native int clrtoeol();

    @Import(name = "wrefresh")
    public static native int wrefresh(Window window);

    @Import(name = "wnoutrefresh")
    public static native int wnoutrefresh(Window window);

    @Import(name = "werase")
    public static native int werase(Window window);

    @Import(name = "wclear")
    public static native int wclear(Window window);

    @Import(name = "wclrtobot")
    public static native int wclrtobot(Window window);

    @Import(name = "wclrtoeol")
    public static native int wclrtoeol(Window window);

    @Import(name = "touchwin")
    public static native int touchwin(Window window);

    @Import(name = "doupdate")
    public static native int doupdate();

    @Import(name = "move")
    public static native int move(int y, int x);

    @Import(name = "wmove")
    public static native int wmove(Window window, int y, int x);

    @Import(name = "addch")
    public static native int addch(int ch);

    @Import(name = "waddch")
    public static native int waddch(Window window, int ch);

    @Import(name = "mvaddch")
    public static native int mvaddch(int y, int x, int ch);

    @Import(name = "mvwaddch")
    public static native int mvwaddch(Window window, int y, int x, int ch);

    public static int addstr(String text)
    {
        Address pointer = Strings.toC(text);
        try
        {
            return addstrNative(pointer);
        }
        finally
        {
            free(pointer);
        }
    }

    @Import(name = "addstr")
    private static native int addstrNative(Address text);

    public static int waddstr(Window window, String text)
    {
        Address pointer = Strings.toC(text);
        try
        {
            return waddstrNative(window, pointer);
        }
        finally
        {
            free(pointer);
        }
    }

    @Import(name = "waddstr")
    private static native int waddstrNative(Window window, Address text);

    public static int mvaddstr(int y, int x, String text)
    {
        Address pointer = Strings.toC(text);
        try
        {
            return mvaddstrNative(y, x, pointer);
        }
        finally
        {
            free(pointer);
        }
    }

    @Import(name = "mvaddstr")
    private static native int mvaddstrNative(int y, int x, Address text);

    public static int mvwaddstr(Window window, int y, int x, String text)
    {
        Address pointer = Strings.toC(text);
        try
        {
            return mvwaddstrNative(window, y, x, pointer);
        }
        finally
        {
            free(pointer);
        }
    }

    @Import(name = "mvwaddstr")
    private static native int mvwaddstrNative(Window window, int y, int x, Address text);

    public static int addnstr(String text, int length)
    {
        Address pointer = Strings.toC(text);
        try
        {
            return addnstrNative(pointer, length);
        }
        finally
        {
            free(pointer);
        }
    }

    @Import(name = "addnstr")
    private static native int addnstrNative(Address text, int length);

    public static int waddnstr(Window window, String text, int length)
    {
        Address pointer = Strings.toC(text);
        try
        {
            return waddnstrNative(window, pointer, length);
        }
        finally
        {
            free(pointer);
        }
    }

    @Import(name = "waddnstr")
    private static native int waddnstrNative(Window window, Address text, int length);

    @Import(name = "scrollok")
    public static native int scrollok(Window window, boolean enabled);

    @Import(name = "wscrl")
    public static native int wscrl(Window window, int lines);

    @Import(name = "getmaxy")
    public static native int getmaxy(Window window);

    @Import(name = "getmaxx")
    public static native int getmaxx(Window window);

    @Import(name = "getcury")
    public static native int getcury(Window window);

    @Import(name = "getcurx")
    public static native int getcurx(Window window);


    // Colours and attributes.
    @Import(name = "has_colors")
    public static native boolean has_colors();

    @Import(name = "can_change_color")
    public static native boolean can_change_color();

    @Import(name = "start_color")
    public static native int start_color();

    @Import(name = "use_default_colors")
    public static native int use_default_colors();

    @Import(name = "init_pair")
    public static native int init_pair(short pair, short foreground, short background);

    @Import(name = "init_color")
    public static native int init_color(short color, short red, short green, short blue);

    @Import(name = "COLOR_PAIR")
    public static native int COLOR_PAIR(int pair);

    @Import(name = "PAIR_NUMBER")
    public static native int PAIR_NUMBER(int attributes);

    @Import(name = "attron")
    public static native int attron(int attributes);

    @Import(name = "attroff")
    public static native int attroff(int attributes);

    @Import(name = "attrset")
    public static native int attrset(int attributes);

    @Import(name = "wattron")
    public static native int wattron(Window window, int attributes);

    @Import(name = "wattroff")
    public static native int wattroff(Window window, int attributes);

    @Import(name = "wattrset")
    public static native int wattrset(Window window, int attributes);

    // Character cells use the low 32 bits, including ncurses attribute bits.
    @Import(name = "hline")
    public static native int hline(int character, int length);

    @Import(name = "vline")
    public static native int vline(int character, int length);

    @Import(name = "whline")
    public static native int whline(Window window, int character, int length);

    @Import(name = "wvline")
    public static native int wvline(Window window, int character, int length);

    @Import(name = "box")
    public static native int box(Window window, int vertical, int horizontal);

    // Header constants and globals are read at runtime to match the native library.
    @Variable
    @Import(name = "stdscr")
    public static native Window stdscr();

    @Variable
    @Import(name = "LINES")
    public static native int LINES();

    @Variable
    @Import(name = "COLS")
    public static native int COLS();

    @Variable
    @Import(name = "COLORS")
    public static native int COLORS();

    @Variable
    @Import(name = "COLOR_PAIRS")
    public static native int COLOR_PAIRS();

    @Variable
    @Import(name = "OK")
    public static native int OK();

    @Variable
    @Import(name = "ERR")
    public static native int ERR();

    @Variable
    @Import(name = "KEY_UP")
    public static native int KEY_UP();

    @Variable
    @Import(name = "KEY_DOWN")
    public static native int KEY_DOWN();

    @Variable
    @Import(name = "KEY_LEFT")
    public static native int KEY_LEFT();

    @Variable
    @Import(name = "KEY_RIGHT")
    public static native int KEY_RIGHT();

    @Variable
    @Import(name = "KEY_HOME")
    public static native int KEY_HOME();

    @Variable
    @Import(name = "KEY_END")
    public static native int KEY_END();

    @Variable
    @Import(name = "KEY_NPAGE")
    public static native int KEY_NPAGE();

    @Variable
    @Import(name = "KEY_PPAGE")
    public static native int KEY_PPAGE();

    @Variable
    @Import(name = "KEY_BACKSPACE")
    public static native int KEY_BACKSPACE();

    @Variable
    @Import(name = "KEY_DC")
    public static native int KEY_DC();

    @Variable
    @Import(name = "KEY_IC")
    public static native int KEY_IC();

    @Variable
    @Import(name = "KEY_ENTER")
    public static native int KEY_ENTER();

    @Variable
    @Import(name = "KEY_RESIZE")
    public static native int KEY_RESIZE();

    @Variable
    @Import(name = "COLOR_BLACK")
    public static native int COLOR_BLACK();

    @Variable
    @Import(name = "COLOR_RED")
    public static native int COLOR_RED();

    @Variable
    @Import(name = "COLOR_GREEN")
    public static native int COLOR_GREEN();

    @Variable
    @Import(name = "COLOR_YELLOW")
    public static native int COLOR_YELLOW();

    @Variable
    @Import(name = "COLOR_BLUE")
    public static native int COLOR_BLUE();

    @Variable
    @Import(name = "COLOR_MAGENTA")
    public static native int COLOR_MAGENTA();

    @Variable
    @Import(name = "COLOR_CYAN")
    public static native int COLOR_CYAN();

    @Variable
    @Import(name = "COLOR_WHITE")
    public static native int COLOR_WHITE();

    @Variable
    @Import(name = "A_NORMAL")
    public static native int A_NORMAL();

    @Variable
    @Import(name = "A_STANDOUT")
    public static native int A_STANDOUT();

    @Variable
    @Import(name = "A_UNDERLINE")
    public static native int A_UNDERLINE();

    @Variable
    @Import(name = "A_REVERSE")
    public static native int A_REVERSE();

    @Variable
    @Import(name = "A_BLINK")
    public static native int A_BLINK();

    @Variable
    @Import(name = "A_DIM")
    public static native int A_DIM();

    @Variable
    @Import(name = "A_BOLD")
    public static native int A_BOLD();

    @Variable
    @Import(name = "A_ALTCHARSET")
    public static native int A_ALTCHARSET();

    @Variable
    @Import(name = "ACS_HLINE")
    public static native int ACS_HLINE();

    @Variable
    @Import(name = "ACS_VLINE")
    public static native int ACS_VLINE();

    @Variable
    @Import(name = "ACS_ULCORNER")
    public static native int ACS_ULCORNER();

    @Variable
    @Import(name = "ACS_URCORNER")
    public static native int ACS_URCORNER();

    @Variable
    @Import(name = "ACS_LLCORNER")
    public static native int ACS_LLCORNER();

    @Variable
    @Import(name = "ACS_LRCORNER")
    public static native int ACS_LRCORNER();

    @Import(name = "KEY_F")
    public static native int KEY_F(int number);
}
