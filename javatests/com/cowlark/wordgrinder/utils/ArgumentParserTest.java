package com.cowlark.wordgrinder.utils;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertThrows;
import static org.junit.Assert.fail;

import com.google.common.collect.ImmutableList;
import org.junit.Test;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.function.ToIntFunction;

/**
 * Exercises the Lua argument-parser fixtures and callback consumption semantics.
 */
public class ArgumentParserTest
{
    @Test
    public void matchesLuaArgumentParserFixtures()
    {
        List<Example> examples = List.of(
                new Example(List.of(), List.of()),
                new Example(List.of("--long"), List.of("long")),
                new Example(List.of("--long", "-s"), List.of("long", "s")),
                new Example(List.of("--longparam", "7"), List.of("long=7")),
                new Example(List.of("--longparam", "7", "-s"), List.of("long=7", "s")),
                new Example(List.of("-s"), List.of("s")),
                new Example(List.of("-s", "--long"), List.of("s", "long")),
                new Example(List.of("-p", "7", "--long"), List.of("p=7", "long")),
                new Example(List.of("-p7", "--long"), List.of("p=7", "long")),
                new Example(List.of("fnord"), List.of("file=fnord")),
                new Example(List.of("-s", "fnord"), List.of("s", "file=fnord")),
                new Example(List.of("-s", "fnord", "--long"), List.of("s", "file=fnord", "long")),
                new Example(List.of("--blah"), List.of("unknown=blah")),
                new Example(List.of("-s", "--blah"), List.of("s", "unknown=blah")),
                new Example(List.of("-s", "--blah", "--long"), List.of("s", "unknown=blah")));
        for (Example example : examples)
        {
            List<String> log = new ArrayList<>();
            Map<String, ToIntFunction<ImmutableList<String>>> callbacks = Map.of(
                    "long", args -> {
                        log.add("long");
                        return 0;
                    }, "s", args -> {
                        log.add("s");
                        return 0;
                    }, "longparam", args -> {
                        log.add("long=" + args.get(0));
                        return 1;
                    }, "p", args -> {
                        log.add("p=" + args.get(0));
                        return 1;
                    });
            parser(callbacks)
                    .onFilenames(args -> {
                        log.add("file=" + args.get(0));
                        return 1;
                    })
                    .onUnknownOption(option -> log.add("unknown=" + option))
                    .parse(ImmutableList.copyOf(example.arguments()));
            assertEquals(example.arguments().toString(), example.expected(), log);
        }
    }

    /* Long, attached-short and filename callbacks all see a stable argument snapshot. */
    @Test
    public void suppliesAllRemainingArgumentsAndHonoursConsumptionCounts()
    {
        ImmutableList<String> argv =
                ImmutableList.of("--pair", "a", "b", "-pvalue", "file", "tail");
        List<ImmutableList<String>> supplied = new ArrayList<>();
        Map<String, ToIntFunction<ImmutableList<String>>> callbacks = Map.of(
                "pair", args -> {
                    supplied.add(args);
                    return 2;
                }, "p", args -> {
                    supplied.add(args);
                    return 1;
                });
        parser(callbacks).onFilenames(args -> {
            supplied.add(args);
            return 2;
        }).onUnknownOption(option -> fail("Unexpected option " + option)).parse(argv);
        assertEquals(List.of("--pair", "a", "b", "-pvalue", "file", "tail"), argv);
        assertEquals(
                List.of(
                        List.of("a", "b", "-pvalue", "file", "tail"),
                        List.of("value", "file", "tail"),
                        List.of("file", "tail")), supplied);
        assertThrows(UnsupportedOperationException.class, () -> supplied.get(0).clear());
    }

    /* Unknown options stop immediately without changing the input. */
    @Test
    public void reportsUnknownNamesAndPreservesInput()
    {
        for (String option : List.of("--unknown", "-unknown", "--", "-", "--long=value"))
        {
            ImmutableList<String> argv = ImmutableList.of(option, "remaining");
            List<String> unknown = new ArrayList<>();
            ArgumentParser.builder().onFilenames(args -> {
                fail("Unexpected filename");
                return 1;
            }).onUnknownOption(unknown::add).parse(argv);
            String expected = option.startsWith("--") ?
                    option.substring(2) :
                    option.length() > 1 ? option.substring(1, 2) : "";
            assertEquals(List.of(expected), unknown);
            assertEquals(List.of(option, "remaining"), argv);
        }
    }

    /* Negative counts, and zero counts for implicitly supplied arguments, are malformed. */
    @Test
    public void rejectsMalformedConsumptionCounts()
    {
        Map<String, ToIntFunction<ImmutableList<String>>> callbacks =
                Map.of("bad", args -> -1, "p", args -> 0, "m", args -> Integer.MIN_VALUE);
        for (String option : List.of("--bad", "-pattached", "filename", "-mattached"))
        {
            ImmutableList<String> argv = ImmutableList.of(option, "remaining");
            IllegalArgumentException error = assertThrows(
                    IllegalArgumentException.class,
                    () -> parser(callbacks)
                            .onFilenames(args -> 0)
                            .onUnknownOption(unknown -> fail("Unexpected unknown option"))
                            .parse(argv));
            assertEquals("malformed argument", error.getMessage());
            assertEquals(List.of(option, "remaining"), argv);
        }
    }

    /* Excess counts stop parsing while preserving the original input. */
    @Test
    public void excessConsumptionStopsAtEndOfInput()
    {
        ImmutableList<String> argv = ImmutableList.of("--consume", "one");
        ArgumentParser.builder().onOption("consume", args -> 5).onFilenames(args -> {
            fail("Consumed filename reached callback");
            return 1;
        }).onUnknownOption(unknown -> fail("Unexpected unknown option")).parse(argv);
        assertEquals(List.of("--consume", "one"), argv);
    }

    /* Empty strings are filenames and the original input remains intact. */
    @Test
    public void immutableInputIsPreserved()
    {
        ImmutableList<String> argv = ImmutableList.of("-s", "");
        List<String> filenames = new ArrayList<>();
        ArgumentParser.builder().onOption("s", args -> 0).onFilenames(args -> {
            filenames.add(args.get(0));
            return 1;
        }).onUnknownOption(unknown -> fail("Unexpected unknown option")).parse(argv);
        assertEquals(ImmutableList.of("-s", ""), argv);
        assertEquals(List.of(""), filenames);
    }

    /* Builders retain their handlers across parses without sharing them with other instances. */
    @Test
    public void parsersAreReusableAndIndependent()
    {
        List<String> log = new ArrayList<>();
        ArgumentParser parser = ArgumentParser.builder().onOption(
                "s", args -> {
                    log.add("s");
                    return 0;
                }).onFilenames(args -> {
            log.add(args.get(0));
            return 1;
        });
        parser.parse(ImmutableList.of("-s", "first"));
        parser.parse(ImmutableList.of("second", "-s"));
        assertEquals(List.of("s", "first", "second", "s"), log);
        assertThrows(
                IllegalArgumentException.class,
                () -> ArgumentParser.builder().parse(ImmutableList.of("-s")));
    }

    /* Register fixture handlers through the same fluent API as application callers. */
    private ArgumentParser parser(Map<String, ToIntFunction<ImmutableList<String>>> callbacks)
    {
        ArgumentParser parser = ArgumentParser.builder();
        callbacks.forEach(parser::onOption);
        return parser;
    }

    /* Keep the original Lua cases as explicit input/output fixtures. */
    private record Example(List<String> arguments, List<String> expected)
    {
    }

}
