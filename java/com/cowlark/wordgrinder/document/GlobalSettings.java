package com.cowlark.wordgrinder.document;

import com.cowlark.wordgrinder.addons.debug.DebugGlobalSettings;
import com.cowlark.wordgrinder.addons.directories.DirectoriesGlobalSettings;
import com.cowlark.wordgrinder.addons.gui.GuiGlobalSettings;
import com.cowlark.wordgrinder.addons.lookandfeel.LookAndFeelGlobalSettings;
import com.cowlark.wordgrinder.addons.recents.RecentsGlobalSettings;
import com.cowlark.wordgrinder.addons.spillchocker.SpillchockerGlobalSettings;
import com.cowlark.wordgrinder.fileio.Dumpable;
import com.cowlark.wordgrinder.fileio.RemainingDumpables;
import com.cowlark.wordgrinder.fileio.TMagic;
import com.cowlark.wordgrinder.fileio.Undumper;

import java.io.BufferedReader;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.Map;

public class GlobalSettings
{
    /* Global addon settings depend only on their separate settings libraries. */
    @Dumpable public DebugGlobalSettings debug = new DebugGlobalSettings();
    @Dumpable public DirectoriesGlobalSettings directories = new DirectoriesGlobalSettings();
    @Dumpable public GuiGlobalSettings gui = new GuiGlobalSettings();
    @Dumpable public LookAndFeelGlobalSettings lookandfeel = new LookAndFeelGlobalSettings();
    @Dumpable public RecentsGlobalSettings recents = new RecentsGlobalSettings();
    @Dumpable public SpillchockerGlobalSettings systemdictionary = new SpillchockerGlobalSettings();

    /* Preserve settings which have not yet been given Java definitions. */
    @RemainingDumpables public Map<String, String> remaining;

    public static GlobalSettings loadGlobalSettings() throws IOException
    {
        /* Decode settings as UTF-8 before passing the text to Undumper. */
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(
                new FileInputStream("/home/dg/.wordgrinder/settings.dat"), StandardCharsets.UTF_8)))
        {
            String magic = reader.readLine();
            if (!magic.equals(TMagic.TMAGIC))
                throw new IOException("Invalid TMagic file");

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
