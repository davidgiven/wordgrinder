package com.cowlark.wordgrinder.addons.smartquotes;

import com.cowlark.wordgrinder.fileio.Dumpable;
import org.jspecify.annotations.NonNull;
import org.jspecify.annotations.Nullable;

/**
 * Settings stored in documentSet.addons; field names match the Lua save format.
 */
public class SmartQuotesDocumentSetSettings
{
    /* Initialise the defaults used when registering the Lua addon. */
    @Dumpable public boolean doublequotes = false;
    @Dumpable public boolean singlequotes = false;
    @Dumpable public boolean notinraw = true;
    @Dumpable public @NonNull String leftdouble = "“";
    @Dumpable public @NonNull String rightdouble = "”";
    @Dumpable public @NonNull String leftsingle = "‘";
    @Dumpable public @NonNull String rightsingle = "’";

    /* Preserve the alternate key written by the Lua configuration dialogue. */
    @Dumpable public @Nullable Boolean notinrawquotes;
}
