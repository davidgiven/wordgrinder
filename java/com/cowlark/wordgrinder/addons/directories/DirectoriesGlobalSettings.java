package com.cowlark.wordgrinder.addons.directories;

import com.cowlark.wordgrinder.fileio.Dumpable;
import org.jspecify.annotations.Nullable;

/**
 * Settings stored in globalSettings; field names match the Lua save format.
 */
public class DirectoriesGlobalSettings
{
    /* Platform configuration supplies the default path when available. */
    @Dumpable public @Nullable String templates;
    @Dumpable public @Nullable String autosaves;
}
