package com.cowlark.wordgrinder.addons.autosave;

import com.cowlark.wordgrinder.fileio.Dumpable;
import org.jspecify.annotations.Nullable;

/**
 * Settings stored in documentSet.addons; field names match the Lua save format.
 */
public class AutosaveDocumentSetSettings
{
    /* Initialise the defaults used when registering the Lua addon. */
    @Dumpable public boolean enabled = false;
    @Dumpable public double period = 10;
    @Dumpable public String pattern = "%F.autosave.%T.wg";
    @Dumpable public @Nullable Long lastsaved;
}
