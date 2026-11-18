package com.cowlark.wordgrinder.addons.statusbar_pagecount;

import com.cowlark.wordgrinder.fileio.Dumpable;

/**
 * Settings stored in documentSet.addons; field names match the Lua save format.
 */
public class StatusbarPageCountDocumentSetSettings
{
    /* Initialise the defaults used when registering the Lua addon. */
    @Dumpable public boolean enabled = false;
    @Dumpable public double wordsperpage = 250;
}
