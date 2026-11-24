package com.cowlark.wordgrinder.fileio;

import static org.junit.Assert.assertArrayEquals;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertSame;
import static org.junit.Assert.assertThrows;
import static org.junit.Assert.assertTrue;
import static org.junit.Assert.fail;

import org.junit.Test;
import java.io.BufferedReader;
import java.io.IOException;
import java.io.PrintWriter;
import java.io.StringReader;
import java.io.StringWriter;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public final class UndumperTest
{
    /**
     * Runs the same reflection checks in a TeaVM C executable.
     */
    public static void main(String[] args) throws IOException
    {
        var tests = new UndumperTest();
        tests.restoresScalarsInheritedPrivateFieldsAndEscapes();
        tests.constructsNestedObjectsAndTypedContainers();
        tests.unknownNestedPathsAndRawValuesSurviveRepeatedRoundTrips();
        tests.nearestRemainingFieldOwnsRelativeUnknownPaths();
        tests.roundTripsOneOffsetFields();
        System.out.println("Undumper TeaVM checks passed");
    }

    private static void load(Object target, String text) throws IOException
    {
        new Undumper().undump(target, new BufferedReader(new StringReader(text)));
    }

    private static String dump(Object target)
    {
        /* Capture character output directly, without an encoding conversion. */
        var output = new StringWriter();
        new Dumper().dump(target, new PrintWriter(output));
        return output.toString();
    }

    /* Translate opted-in fields in both directions, including the unset sentinel. */
    @Test
    public void roundTripsOneOffsetFields() throws IOException
    {
        var offsets = new Offsets();
        String text = ".cp: 1\n.unchanged: 4\n.wide: 2147483648\n";
        assertEquals(text, dump(offsets));

        /* Load one-based offsets and retain the default for the omitted mark. */
        var loaded = new Offsets();
        load(loaded, text.replace(".cp: 1", ".cp: 3"));
        assertEquals(2, loaded.cursor);
        assertEquals(-1, loaded.mark);
        assertEquals(4, loaded.unchanged);
        assertEquals(Integer.MAX_VALUE, loaded.wide);

        /* Older dumps may still contain an explicit zero for an unset mark. */
        loaded.mark = 2;
        load(loaded, ".mark: 0\n");
        assertEquals(-1, loaded.mark);
    }

    /* Include an aliased index, a sentinel and an ordinary scalar. */
    private static final class Offsets
    {
        @Dumpable(value = "cp", oneOffset = true) int cursor;
        @Dumpable(oneOffset = true) int mark = -1;
        @Dumpable int unchanged = 4;
        @Dumpable(oneOffset = true) int wide = Integer.MAX_VALUE;
    }

    @Test
    public void restoresScalarsInheritedPrivateFieldsAndEscapes() throws IOException
    {
        Data data = new Data();
        load(
                data,
                ".renamed: \"a\\\"b\\\\c\\nd\\ré😀\u0011\"\n.count: 7\n.enabled: true\n" +
                        ".character: \"é\"\n.fraction: 1.25\n.large: 9223372036854775807\n");
        assertEquals("a\"b\\c\nd\ré😀\u0011", ((Parent) data).name);
        assertEquals(7, data.count);
        assertTrue(data.enabled);
        assertEquals('é', data.character);
        assertEquals(1.25, data.fraction, 0);
        assertEquals(Long.valueOf(Long.MAX_VALUE), data.large);
    }

    @Test
    public void constructsNestedObjectsAndTypedContainers() throws IOException
    {
        Data data = new Data();
        load(
                data,
                ".child.text: \"hello\"\n.children.2.text: \"second\"\n" +
                        ".children.1.text: \"first\"\n.numbers.answer: 42\n.values.2: 8\n.values" +
                        ".1: 7\n");
        assertEquals("hello", data.child.text);
        assertEquals("first", data.children.get(0).text);
        assertEquals("second", data.children.get(1).text);
        assertEquals(Integer.valueOf(42), data.numbers.get("answer"));
        assertArrayEquals(new int[]{7, 8}, data.values);
    }

    @Test
    public void unknownNestedPathsAndRawValuesSurviveRepeatedRoundTrips() throws IOException
    {
        String text = ".child.future.deep: \"a\\\\b\\n😀\"\n.child.text: \"known\"\n" +
                ".count: 4\n.future.number: 1.200e+03\n.future.truth: false\n";
        Data data = new Data();
        load(data, text);
        assertEquals(
                Map.of(
                        ".child.future.deep",
                        "\"a\\\\b\\n😀\"",
                        ".future.number",
                        "1.200e+03",
                        ".future.truth",
                        "false"), ((Parent) data).remaining);
        String first = dump(data);
        Data copy = new Data();
        load(copy, first);
        assertEquals(first, dump(copy));
        assertTrue(first.contains(".future.number: 1.200e+03\n"));
        assertTrue(first.contains(".child.future.deep: \"a\\\\b\\n😀\"\n"));
    }

    @Test
    public void nearestRemainingFieldOwnsRelativeUnknownPaths() throws IOException
    {
        Owner owner = new Owner();
        load(owner, ".nested.text: \"known\"\n.nested.extra.deep: 17\n.root: true\n");
        assertEquals(Map.of(".extra.deep", "17"), owner.nested.remaining);
        assertEquals(Map.of(".root", "true"), owner.remaining);
        assertEquals(".nested.extra.deep: 17\n.nested.text: \"known\"\n.root: true\n", dump(owner));
    }

    @Test
    public void missingPropertiesRetainDefaultsAndExistingNestedObjects() throws IOException
    {
        Data data = new Data();
        data.count = 12;
        data.child = new Child();
        Child child = data.child;
        load(data, ".child.text: \"hello\"\n");
        assertEquals(12, data.count);
        assertSame(child, data.child);
    }

    @Test
    public void malformedValuesConflictingPathsAndInvalidAssignmentsAreErrors()
    {
        for (String text : List.of(
                "garbage\n",
                ".x: nil\n",
                ".x: \"bad\\q\"\n",
                ".x: 1\n.x: 2\n",
                ".x: 1\n.x.y: 2\n",
                ".x.y: 1\n.x: 2\n",
                ".x..y: 1\n",
                ".count: 2147483648\n",
                ".count: 1.5\n",
                ".enabled: 1\n",
                ".values.0: 1\n"))
            assertThrows(text, IllegalArgumentException.class, () -> load(new Data(), text));
        assertThrows(IllegalArgumentException.class, () -> load(new Child(), ".unknown.path: 7\n"));
    }

    @Test
    public void finalScalarFieldsAndConflictingRemainingEntriesAreErrors()
    {
        assertThrows(IllegalArgumentException.class, () -> load(new Immutable(1), ".count: 2\n"));
        Local local = new Local();
        local.text = "known";
        local.remaining = Map.of(".text", "\"stale\"");
        assertThrows(IllegalArgumentException.class, () -> dump(local));
    }

    @Test
    public void malformedRemainingEntriesAndInvalidAnnotationsAreErrors()
    {
        Local local = new Local();
        for (String key : List.of(".x..y", ".x.", ".x: y", ".x\ny"))
        {
            local.remaining = Map.of(key, "7");
            assertThrows(IllegalArgumentException.class, () -> dump(local));
        }
        local.remaining = Map.of(".x", "not a value");
        assertThrows(IllegalArgumentException.class, () -> dump(local));
        local.remaining = Map.of(".text.nested", "7");
        local.text = "scalar";
        assertThrows(IllegalArgumentException.class, () -> dump(local));
        assertThrows(IllegalArgumentException.class, () -> dump(new WrongRemainingType()));
        assertThrows(
                IllegalArgumentException.class,
                () -> load(new WrongRemainingType(), ".x: 7\n"));
    }

    @Test
    public void callerReadersAreNotClosed() throws IOException
    {
        var input = new BufferedReader(new StringReader(".count: 1\n"))
        {
            @Override
            public void close()
            {
                fail("Caller owns input");
            }
        };
        new Undumper().undump(new Data(), input);
    }

    private static class Parent
    {
        @Dumpable("renamed") private String name;
        @RemainingDumpables private Map<String, String> remaining = new LinkedHashMap<>();
    }

    private static final class Data extends Parent
    {
        @Dumpable int count;
        @Dumpable boolean enabled;
        @Dumpable char character;
        @Dumpable double fraction;
        @Dumpable Long large;
        @Dumpable Child child;
        @Dumpable List<Child> children = new ArrayList<>();
        @Dumpable Map<String, Integer> numbers;
        @Dumpable int[] values;
    }

    private static final class Child
    {
        @Dumpable String text;
    }

    private static final class Local
    {
        @Dumpable String text;
        @RemainingDumpables Map<String, String> remaining;
    }

    private static final class Owner
    {
        @Dumpable Local nested = new Local();
        @RemainingDumpables Map<String, String> remaining = new LinkedHashMap<>();
    }

    private record Immutable(@Dumpable int count)
    {
    }

    private static final class WrongRemainingType
    {
        @RemainingDumpables Map<String, Integer> remaining;
    }
}
