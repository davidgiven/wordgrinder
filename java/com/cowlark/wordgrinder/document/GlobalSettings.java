package com.cowlark.wordgrinder.document;

import java.io.BufferedReader;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.Map;

public class GlobalSettings
{
    @RemainingDumpables public Map<String, String> remaining;

    public static GlobalSettings loadGlobalSettings() throws IOException
    {
        /* Decode settings as UTF-8 before passing the text to Undumper. */
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(
                new FileInputStream("/home/dg/.wordgrinder/settings.dat"), StandardCharsets.UTF_8)))
        {
            reader.readLine();

            Wrapper wrapper = new Wrapper();
            new Undumper().undump(wrapper, reader);
            return wrapper.globalSettings;
        }
    }

    private static class Wrapper
    {
        @Dumpable public GlobalSettings globalSettings;
    }
}
