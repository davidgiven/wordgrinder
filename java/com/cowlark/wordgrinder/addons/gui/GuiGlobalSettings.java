package com.cowlark.wordgrinder.addons.gui;

import com.cowlark.wordgrinder.fileio.Dumpable;

/**
 * Settings stored in globalSettings; field names match the Lua save format.
 */
public class GuiGlobalSettings
{
    /* Initialise the defaults used when registering the Lua addon. */
    @Dumpable public int font_size = 20;
    @Dumpable public int window_width = 800;
    @Dumpable public int window_height = 600;
    @Dumpable public String font_regular = "extras/fonts/FantasqueSansMono-Regular.ttf";
    @Dumpable public String font_italic = "extras/fonts/FantasqueSansMono-Italic.ttf";
    @Dumpable public String font_bold = "extras/fonts/FantasqueSansMono-Bold.ttf";
    @Dumpable public String font_bolditalic = "extras/fonts/FantasqueSansMono-BoldItalic.ttf";
}
