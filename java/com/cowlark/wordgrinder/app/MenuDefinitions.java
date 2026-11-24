package com.cowlark.wordgrinder.app;

import com.cowlark.wordgrinder.ui.Menu;
import com.cowlark.wordgrinder.ui.Menu.Item;
import com.google.common.collect.ImmutableList;

public class MenuDefinitions
{
    public static Menu TOPLEVEL = new Menu("Toplevel menu",
                                           ImmutableList.of(new Item("menu item 1", null, "1", null, null, null)));
}
