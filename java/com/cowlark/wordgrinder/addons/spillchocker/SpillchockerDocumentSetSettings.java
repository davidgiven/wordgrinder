package com.cowlark.wordgrinder.addons.spillchocker;

import com.cowlark.wordgrinder.fileio.Dumpable;

/**
 * Settings stored in documentSet.addons; field names match the Lua save format.
 */
public class SpillchockerDocumentSetSettings
{
    /* Initialise the defaults used when registering the Lua addon. */
    @Dumpable public boolean enabled = false;
    @Dumpable public boolean usesystemdictionary = true;
    @Dumpable public boolean useuserdictionary = true;
}
