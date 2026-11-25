package com.cowlark.wordgrinder.fileio;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertThrows;

import org.junit.Test;
import java.io.PrintWriter;
import java.io.StringWriter;
import java.util.LinkedHashMap;
import java.util.List;

public final class DumperTest
{
    private static String dump(Object object)
    {
        StringWriter output = new StringWriter();
        new Dumper().dump(object, new PrintWriter(output));
        return output.toString();
    }

    @Test
    public void onlyAnnotatedInstanceFieldsAreWrittenIncludingInheritedPrivateFields()
    {
        assertEquals(".alpha: 7\n.zebra: \"hello\"\n", dump(new Child()));
    }

    @Test
    public void recordFieldsAndExplicitNamesAreSupported()
    {
        assertEquals(".enabled: false\n.oldname: \"value\"\n", dump(new Value("value", false)));
    }

    @Test
    public void nestedValuesUseDottedPathsAndOneBasedIndices()
    {
        var values = new LinkedHashMap<String, Object>();
        values.put("z", new int[]{2, 3});
        values.put("a", List.of(new Value("first", true), new Value("second", false)));
        values.put("_transient", "ignored");
        assertEquals(
                ".a.1.enabled: true\n.a.1.oldname: \"first\"\n" +
                        ".a.2.enabled: false\n.a.2.oldname: \"second\"\n.z.1: 2\n.z.2: 3\n",
                dump(values));
    }

    @Test
    public void stringsUseTheOriginalEscapesAndKeepUnicodeAndStyleCodes()
    {
        assertEquals(": \"a\\\"b\\\\c\\nd\\ré😀\u0011\"\n", dump("a\"b\\c\nd\ré😀\u0011"));
    }

    @Test
    public void scalarValuesAndEmptyObjectsAreSupported()
    {
        assertEquals(": true\n", dump(true));
        assertEquals(": -9223372036854775808\n", dump(Long.MIN_VALUE));
        assertEquals(": 9223372036854775807\n", dump(Long.MAX_VALUE));
        assertEquals("", dump(new Object()));
        assertEquals("", dump(new String[0]));
    }

    @Test
    public void sharedObjectsCanBeRepeatedButCyclesAreRejected()
    {
        var repeated = new Value("x", true);
        assertEquals(
                dump(List.of(new Value("x", true), new Value("x", true))),
                dump(List.of(repeated, repeated)));
        var cyclic = new LinkedHashMap<String, Object>();
        cyclic.put("self", cyclic);
        assertThrows(IllegalArgumentException.class, () -> dump(cyclic));
    }

    @Test
    public void invalidNumbersAndMapKeysAreRejected()
    {
        assertThrows(IllegalArgumentException.class, () -> dump(Double.NaN));
        assertThrows(IllegalArgumentException.class, () -> dump(Double.POSITIVE_INFINITY));
        assertThrows(IllegalArgumentException.class, () -> dump(1.0));
        assertThrows(IllegalArgumentException.class, () -> dump(1.5f));
        assertThrows(IllegalArgumentException.class, () -> dump(java.util.Map.of(1, "value")));
    }

    private static class Parent
    {
        @Dumpable private int alpha = 7;
        private String ignored = "not saved";
    }

    private static final class Child extends Parent
    {
        @Dumpable private static String staticField = "not saved";
        @Dumpable private String zebra = "hello";
        @Dumpable private String absent;
    }

    private record Value(@Dumpable("oldname") String name, @Dumpable boolean enabled)
    {
    }
}
