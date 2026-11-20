package com.cowlark.wordgrinder;

import static java.lang.System.err;

import com.cowlark.wordgrinder.document.Word;
import com.cowlark.wordgrinder.eventbus.EventBus;
import com.cowlark.wordgrinder.nativeinterface.Screen;
import com.cowlark.wordgrinder.nativeinterface.System;
import com.cowlark.wordgrinder.teavm.impl.DisplayImpl;
import com.cowlark.wordgrinder.teavm.impl.ScreenImpl;
import com.cowlark.wordgrinder.teavm.impl.SystemImpl;
import com.cowlark.wordgrinder.ui.Ui;
import com.cowlark.wordgrinder.ui.WrappedLabelWidget;
import com.cowlark.wordgrinder.utils.ArgumentParser;
import com.google.common.collect.ImmutableList;
import java.io.IOException;
import java.io.PrintStream;

public class Main
{
    /* Keep backend selection separate from application execution. */
    private final Screen screen;
    private final Ui ui;
    private final System system;
    private final Word wordRenderer;
    private final EventBus eventBus;

    /* Retain configuration overrides and command-line exit state. */
    private String configFile;
    private boolean exitRequested;

    public Main(Screen screen, System system, Word wordRenderer, EventBus eventBus)
    {
        this.screen = screen;
        this.system = system;
        this.wordRenderer = wordRenderer;
        this.eventBus = eventBus;
        ui = new Ui(screen);
        configFile = system.getConfigDirectory() + "/startup.lua";
    }

    /* The entry point chooses the backend; application logic receives its interface. */
    public static void main(String[] args) throws IOException
    {
        DisplayImpl display = new DisplayImpl();
        new Main(new ScreenImpl(display), new SystemImpl(), new Word(display), new EventBus()).run(
                args);
    }

    /* Preserve the Lua help text, including its configuration-file placeholder. */
    private int doHelp(ImmutableList<String> args)
    {
        err.print("WordGrinder version " + BuildInfo.VERSION + " © 2007-2020 David Given\n");
        if (BuildInfo.DEBUG)
            err.print("(This version has been compiled with debugging enabled.)\n");
        err.print("""
                Syntax: wordgrinder [<options...>] [<filename>]
                Options:
                   -h    --help                Displays this message.
                         --lua file.lua        Loads and executes file.lua and then exits
                                               (remaining arguments are passed to the script)
                         --exec 'lua code'     Loads and executes the supplied code and then exits
                                               (remaining arguments are passed to the script)
                   -c    --convert src dest    Converts from one file format to another
                         --config file.lua     Sets the name of the user config file
                   -r    --recent              Automatically load the most recently used file
                   -8    --no-unicode          Use ISO-8859-1 characters only
                         --no-ncurses-colour   Don't use colours on the terminal

                Only one filename may be specified, which is the name of a WordGrinder
                file to load on startup. If not given, you get a blank document instead.

                To convert documents, use --convert. The file type is autodetected from the
                extension. To specify a document name, use :name as a suffix. e.g.:

                    wordgrinder --convert filename.wg:"Chapter 1" chapter1.odt

                The user config file is a Lua file which is loaded and executed before
                the program starts up (but after any --lua files). It defaults to:

                    %s

                """.formatted(configFile));
        requestExit();
        return args.size();
    }

    /* Exit callbacks also stop startup when an injected System returns from exit(). */
    private void requestExit()
    {
        exitRequested = true;
        system.exit(0);
    }

    /* Reject scripting until the Lua runtime has been ported. */
    private int doLua(ImmutableList<String> args)
    {
        requireArguments(args, 1, "--lua must have an argument");
        throw new UnsupportedOperationException("--lua is not implemented");
    }

    private int doExec(ImmutableList<String> args)
    {
        requireArguments(args, 1, "--exec must have an argument");
        throw new UnsupportedOperationException("--exec is not implemented");
    }

    /* Check conversion arguments before rejecting the unavailable operation. */
    private int doConvert(ImmutableList<String> args)
    {
        requireArguments(args, 2, "--convert must have two arguments");
        throw new UnsupportedOperationException("--convert is not implemented");
    }

    /* Configuration overrides affect later help as well as eventual startup. */
    private int doConfig(ImmutableList<String> args)
    {
        requireArguments(args, 1, "--config must have an argument");
        configFile = args.get(0);
        return 1;
    }

    /* Document startup and recent-file loading have not yet been ported. */
    private int doFilename(ImmutableList<String> args)
    {
        throw new UnsupportedOperationException("Loading a filename is not implemented");
    }

    private int doRecent(ImmutableList<String> args)
    {
        throw new UnsupportedOperationException("--recent is not implemented");
    }

    /* Unicode switching has not yet been exposed by the native interface. */
    private int do8Bit(ImmutableList<String> args)
    {
        throw new UnsupportedOperationException("--no-unicode is not implemented");
    }

    /* The display backend handles this option itself, as in Lua. */
    private int doNothing(ImmutableList<String> args)
    {
        return 0;
    }

    /* Report the same missing-argument diagnostics as the Lua callbacks. */
    private void requireArguments(ImmutableList<String> args, int count, String message)
    {
        if (args.size() < count)
            throw new IllegalArgumentException(message);
    }

    /* Register all Lua command-line options and aliases before processing the input. */
    void parseArguments(ImmutableList<String> args)
    {
        ArgumentParser.builder()
                .onOption("h", this::doHelp)
                .onOption("help", this::doHelp)
                .onOption("lua", this::doLua)
                .onOption("exec", this::doExec)
                .onOption("c", this::doConvert)
                .onOption("convert", this::doConvert)
                .onOption("config", this::doConfig)
                .onOption("8", this::do8Bit)
                .onOption("no-unicode", this::do8Bit)
                .onOption("r", this::doRecent)
                .onOption("recent", this::doRecent)
                .onOption("no-ncurses-colour", this::doNothing)
                .onFilenames(this::doFilename)
                .onUnknownOption(option -> {
                    throw new IllegalArgumentException(
                            "unrecognised option '" + option + "' --- try --help for help");
                })
                .parse(args);
    }

    public void run(String[] args) throws IOException
    {
        /* Command-line exits and errors must complete before initialising the display. */
        try
        {
            parseArguments(ImmutableList.copyOf(args));
        } catch (IllegalArgumentException e)
        {
            err.println("wordgrinder: " + e.getMessage());
            system.exit(1);
            return;
        }
        if (exitRequested)
            return;

        /* Run the demonstration until the main word-processor loop is ported. */
        try
        {
            screen.screenInit(args);
            screen.initScreen();
            try
            {
                ui.newForm().setTitle("This is a form").setSize(40, 2).setStretchy(true)
                        .add(new WrappedLabelWidget(wordRenderer, eventBus)
                                .setBounds(1, 1, -1, -1)
                                .setValue("""
                                        This is a wrapped label. Its text flows across several
                                        lines, and the form grows to fit it.
                                        """)).run();
            } finally
            {
                screen.deinitScreen();
            }
        } catch (Exception e)
        {
            e.printStackTrace();
            system.exit(1);
        }
    }

}
