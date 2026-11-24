package com.cowlark.wordgrinder;

import com.cowlark.wordgrinder.nativeinterface.Screen;
import com.cowlark.wordgrinder.utils.Injector;
import com.cowlark.wordgrinder.nativeinterface.System;
import com.google.common.collect.ImmutableList;
import java.io.ByteArrayOutputStream;
import java.io.PrintStream;
import java.lang.reflect.Proxy;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import org.junit.Test;
import static org.junit.Assert.*;

public class MainTest
{
    /* Help must retain the Lua wording and spacing, and exit before using the display. */
    @Test
    public void helpMatchesLuaVerbatim() throws Exception
    {
        String expected = "WordGrinder version " + BuildInfo.VERSION + " © 2007-2020 David Given\n" + """
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

                    /config/startup.lua

                """;
        for (String option : List.of("-h", "--help"))
        {
            Result result = run(option, "--unknown");
            assertEquals(expected, result.output());
            assertEquals(List.of(0), result.exits());
        }
    }

    /* Configuration changes are visible to subsequent help output. */
    @Test
    public void configOverridesDefaultHelpPath() throws Exception
    {
        Result result = run("--config", "custom.lua", "--help");
        assertTrue(result.output().endsWith("    custom.lua\n\n"));
        assertEquals(List.of(0), result.exits());
    }

    /* Validate required arguments before entering any unported callback implementation. */
    @Test
    public void reportsMissingArguments() throws Exception
    {
        for (String option : List.of("lua", "exec", "config"))
            assertError("--" + option + " must have an argument", "--" + option);
        for (String option : List.of("-c", "--convert"))
        {
            assertError("--convert must have two arguments", option);
            assertError("--convert must have two arguments", option, "source.wg");
        }
    }

    /* Unavailable operations and their aliases fail before any display or exit calls. */
    @Test
    public void rejectsUnimplementedOptions()
    {
        for (ImmutableList<String> args : ImmutableList.of(
                ImmutableList.of("--lua", "script.lua", "argument"),
                ImmutableList.of("--exec", "code", "argument"),
                ImmutableList.of("-csource.wg", "destination.odt"),
                ImmutableList.of("--convert", "source.wg", "destination.odt"),
                ImmutableList.of("-8"), ImmutableList.of("--no-unicode"),
                ImmutableList.of("-r"), ImmutableList.of("--recent"),
                ImmutableList.of("file.wg")))
        {
            Fixture fixture = new Fixture();
            assertThrows(args.toString(), UnsupportedOperationException.class,
                    () -> fixture.main.run(args.toArray(new String[0])));
            assertTrue(fixture.exits.isEmpty());
        }
    }

    /* The backend colour option remains an intentional no-op. */
    @Test
    public void acceptsBackendColourOption()
    {
        new Fixture().main.parseArguments(ImmutableList.of("--no-ncurses-colour"));
    }

    /* CLI errors have the Lua prefix, no stack trace, and exit status one. */
    @Test
    public void reportsUnknownOptions() throws Exception
    {
        assertError("unrecognised option 'unknown' --- try --help for help", "--unknown");
    }

    private void assertError(String message, String... args) throws Exception
    {
        Result result = run(args);
        assertEquals("wordgrinder: " + message + "\n", result.output());
        assertEquals(List.of(1), result.exits());
    }

    /* Capture stderr while allowing injected exit() to return, checking startup still stops. */
    private Result run(String... args) throws Exception
    {
        Fixture fixture = new Fixture();
        ByteArrayOutputStream output = new ByteArrayOutputStream();
        PrintStream previous = java.lang.System.err;
        try (PrintStream err = new PrintStream(output, true, StandardCharsets.UTF_8))
        {
            java.lang.System.setErr(err);
            fixture.main.run(args);
        } finally
        {
            java.lang.System.setErr(previous);
        }
        return new Result(output.toString(StandardCharsets.UTF_8), fixture.exits);
    }

    /* Any screen or display call means command-line processing failed to stop startup. */
    private static <T> T unusedBackend(Class<T> type)
    {
        return type.cast(Proxy.newProxyInstance(type.getClassLoader(), new Class<?>[] {type},
                (proxy, method, args) -> {
                    throw new AssertionError("Unexpected backend call: " + method.getName());
                }));
    }

    private static class Fixture
    {
        final List<Integer> exits = new ArrayList<>();
        final System system = new System()
        {
            public String getConfigDirectory() { return "/config"; }
            public String getExecutablePath() { return null; }
            public void exit(int status) { exits.add(status); }
        };
        final Main main = createMain();

        /* Resolve the entry point with a backend that rejects display initialisation. */
        private Main createMain()
        {
            Injector injector = new Injector();
            injector.bindInstance(Injector.class, injector);
            injector.bindInstance(Screen.class, unusedBackend(Screen.class));
            injector.bindInstance(System.class, system);
            return injector.create(Main.class);
        }
    }

    private record Result(String output, List<Integer> exits) {}
}
