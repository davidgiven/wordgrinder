package com.cowlark.wordgrinder.addons.debug;

import com.cowlark.wordgrinder.fileio.Dumpable;

/**
 * Settings stored in globalSettings; field names match the Lua save format.
 */
public class DebugGlobalSettings
{
    /* Initialise the defaults used when registering the Lua addon. */
    @Dumpable public boolean memory = false;
    @Dumpable public boolean location = false;
    @Dumpable public boolean currentword = false;
}
