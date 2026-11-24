package com.cowlark.wordgrinder.app;

import com.cowlark.wordgrinder.ui.Menu;
import com.cowlark.wordgrinder.ui.Menu.Item;

public class MenuDefinitions
{
    public static Menu SUBMENU = new Menu("submenu",
            Item.command("S1", "submenu item 1", "1", null, null));

    public static Menu TOPLEVEL = new Menu("Toplevel menu",
            Item.command("M1", "menu item 1", "1", null, null),
            Item.SEPARATOR,
            Item.command("M2", "menu item 2", "2", null, null),
            Item.submenu("M3", "3", "Open submenu >", null, SUBMENU));
}
