package com.cowlark.wordgrinder.ui;

import com.cowlark.wordgrinder.nativeinterface.Screen;

import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import com.google.common.collect.ImmutableList;
import org.jspecify.annotations.Nullable;

/**
 * An ordered menu definition, translated from the Menu type and CreateMenu in menu.lua.
 */
public final class Menu
{
    /* Keep the contents replaceable so existing submenu links survive a rebuild. */
    private String label;
    private List<Item> items;
    private Map<String, Item> menuKeys;

    /**
     * Creates a menu with the given title and ordered entries.
     */
    public Menu(String label, List<Item> items)
    {
        replace(label, items);
    }

    /**
     * Creates a menu with the given title and ordered entries.
     */
    public Menu(String label, Item... items)
    {
        replace(label, ImmutableList.copyOf(items));
    }

    /**
     * Rebuilds this menu in place, as for the documents and paragraph styles menus.
     */
    public void replace(String label, List<Item> items)
    {
        /* Validate and index the replacement before changing the current contents. */
        List<Item> replacement = List.copyOf(items);
        Map<String, Item> keys = new HashMap<>();
        Set<String> ids = new HashSet<>();
        for (Item item : replacement)
        {
            if (item.menuKey() != null && keys.putIfAbsent(item.menuKey(), item) != null)
                throw new IllegalArgumentException("Duplicate menu action key " + item.menuKey());
            if (item.id() != null && !ids.add(item.id()))
                throw new IllegalArgumentException("Duplicate menu ID " + item.id());
        }

        /* Publish the new contents once all entries have passed validation. */
        this.label = label;
        this.items = replacement;
        this.menuKeys = keys;
    }

    /**
     * Returns the title displayed above the entries.
     */
    public String label()
    {
        return label;
    }

    /**
     * Returns the entries in display order, including separators.
     */
    public List<Item> items()
    {
        return items;
    }

    /**
     * Finds the entry for a menu-local key, already normalised by the caller.
     */
    public @Nullable Item lookupMenuKey(String key)
    {
        return menuKeys.get(key);
    }

    /**
     * Returns the width of the widest title or entry label in screen cells.
     */
    public int maxWidth(Screen screen)
    {
        int width = screen.getStringWidth(label);
        for (Item item : items)
            width = Math.max(width, screen.getStringWidth(item.label()));
        return width;
    }

    /**
     * A command, submenu link or separator with optional menu and accelerator keys.
     */
    public record Item(
            String label,
            @Nullable String id,
            @Nullable String menuKey,
            @Nullable String accelerator,
            @Nullable VoidAction action,
            @Nullable Menu submenu)
    {
        public static final Item SEPARATOR =
                new Item("-", null, null, null, null, null);

        /**
         * Creates a command entry with its default accelerator.
         */
        public static Item command(
                String id, @Nullable String menuKey, String label,
                @Nullable String accelerator, VoidAction action)
        {
            return new Item(label, id, menuKey, accelerator, action, null);
        }

        /**
         * Creates an entry that opens another menu.
         */
        public static Item submenu(
                String id, @Nullable String menuKey, String label,
                @Nullable String accelerator, Menu submenu)
        {
            return new Item(label, id, menuKey, accelerator, null, submenu);
        }

        /**
         * Identifies the separator label used in the Lua menu definitions.
         */
        public boolean isSeparator()
        {
            return label.equals("-");
        }
    }
}
