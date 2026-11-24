package com.cowlark.wordgrinder.ui;

import com.cowlark.wordgrinder.fileio.Dumpable;
import java.util.LinkedHashMap;
import java.util.Map;

/** Accelerator bindings stored for a document set. */
public class MenuSettings
{
    /* Resolve a key press to a menu item ID. */
    @Dumpable public Map<String, String> itemIdsByAccelerator = new LinkedHashMap<>();

    /* Find the accelerator to display beside a menu item. */
    @Dumpable public Map<String, String> acceleratorsByItemId = new LinkedHashMap<>();
}
