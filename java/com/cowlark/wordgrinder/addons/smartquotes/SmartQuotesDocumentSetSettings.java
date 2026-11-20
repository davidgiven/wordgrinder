package com.cowlark.wordgrinder.addons.smartquotes;

import com.cowlark.wordgrinder.fileio.Dumpable;
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
    @Dumpable public String leftdouble = "“";
    @Dumpable public String rightdouble = "”";
    @Dumpable public String leftsingle = "‘";
    @Dumpable public String rightsingle = "’";

    /* Preserve the alternate key written by the Lua configuration dialogue. */
    @Dumpable public @Nullable Boolean notinrawquotes;
}
