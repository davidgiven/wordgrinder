package com.cowlark.wordgrinder.teavm.impl;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertTrue;

import org.junit.Test;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.concurrent.TimeUnit;

/**
 * Runs the native probe through JUnit4 so the standard test target covers C string interop.
 */
public class CStringTest
{
    /* Extract the packaged native executable and check its assertions and exit status. */
    @Test
    public void stringsAndNativeCallersPreserveUtf8AndBufferLifetimes() throws Exception
    {
        Path executable = Files.createTempFile("wordgrinder-cstring-", ".exe");
        try
        {
            try (var resource = CStringTest.class.getResourceAsStream("/cstring-probe"))
            {
                assertNotNull("Native probe resource", resource);
                Files.copy(resource, executable, java.nio.file.StandardCopyOption.REPLACE_EXISTING);
            }
            assertTrue("Native probe must be executable", executable.toFile().setExecutable(true));

            /* Bound failures so a broken native probe cannot stall the Java test runner. */
            ProcessBuilder command = new ProcessBuilder(executable.toString()).inheritIO();
            command.environment().put("WINDOWS_EXE", "not-the-executable");
            Process process = command.start();
            try
            {
                assertTrue("Native probe timed out", process.waitFor(30, TimeUnit.SECONDS));
                assertEquals("Native probe failed", 0, process.exitValue());
            } finally
            {
                if (process.isAlive())
                    process.destroyForcibly();
            }
        } finally
        {
            Files.deleteIfExists(executable);
        }
    }
}
