package com.cowlark.wordgrinder.app;

import com.cowlark.wordgrinder.app.WordProcessor.TerminateProgramAction;
import com.cowlark.wordgrinder.ui.Action;
import com.cowlark.wordgrinder.ui.Menu;
import com.cowlark.wordgrinder.ui.Menu.Item;

public class MenuDefinitions
{
    public static Menu SUBMENU = new Menu("submenu",
            Item.builder("S1", "1", "submenu item 1").build());

    public static Menu TOPLEVEL = new Menu("Toplevel menu",
            Item.builder("M1", "1", "menu item 1").build(),
            Item.SEPARATOR,
            Item.builder("M2", "2", "menu item 2").build(),
            Item.builder("M3", "3", "Open submenu >").setSubmenu(SUBMENU).build(),
            Item.builder("Q", "X", "Quit").setAction(
                    Action.of(
                            TerminateProgramAction.class)).build());
}
