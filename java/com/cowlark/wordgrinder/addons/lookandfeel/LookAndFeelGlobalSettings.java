package com.cowlark.wordgrinder.addons.lookandfeel;

import com.cowlark.wordgrinder.fileio.Dumpable;

/**
 * Settings stored in globalSettings; field names match the Lua save format.
 */
public class LookAndFeelGlobalSettings
{
    /* Initialise the defaults used when registering the Lua addon. */
    @Dumpable public boolean enabled = false;
    @Dumpable public int maxwidth = 80;
    @Dumpable public boolean terminators = true;
    @Dumpable public boolean denseparagraphs = false;
    @Dumpable public String palette = "Light";
    @Dumpable public String scrollmode = "Fixed";
    @Dumpable public boolean fullstopspaces = false;
}
