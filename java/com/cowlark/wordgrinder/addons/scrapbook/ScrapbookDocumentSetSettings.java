package com.cowlark.wordgrinder.addons.scrapbook;

import com.cowlark.wordgrinder.fileio.Dumpable;
import org.jspecify.annotations.NonNull;

/**
 * Settings stored in documentSet.addons; field names match the Lua save format.
 */
public class ScrapbookDocumentSetSettings
{
    /* Initialise the defaults used when registering the Lua addon. */
    @Dumpable public @NonNull String document = "Scrapbook";
    @Dumpable public boolean timestamp = true;
    @Dumpable public @NonNull String pattern = "Item from '%N' at %T:";
}
