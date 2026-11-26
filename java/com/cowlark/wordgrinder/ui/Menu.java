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

    /** A menu entry or the shared separator. */
    public static final class Item
    {
        /* The separator has no key, identifier or behaviour. */
        public static final Item SEPARATOR = new Item("-", null, null, null, null, null);

        private final String label;
        private final @Nullable String id;
        private final @Nullable String menuKey;
        private final @Nullable String accelerator;
        private final @Nullable VoidAction action;
        private final @Nullable Menu submenu;

        /* Store the completed entry as an immutable value. */
        private Item(String label, @Nullable String id, @Nullable String menuKey,
                @Nullable String accelerator, @Nullable VoidAction action, @Nullable Menu submenu)
        {
            this.label = label;
            this.id = id;
            this.menuKey = menuKey;
            this.accelerator = accelerator;
            this.action = action;
            this.submenu = submenu;
        }

        /** Starts an entry with its required identifier, menu key and label. */
        public static Builder builder(String id, String menuKey, String label)
        {
            return new Builder(id, menuKey, label);
        }

        /* Expose the entry's display and activation properties. */
        public String label()
        {
            return label;
        }

        public @Nullable String id()
        {
            return id;
        }

        public @Nullable String menuKey()
        {
            return menuKey;
        }

        public @Nullable String accelerator()
        {
            return accelerator;
        }

        public @Nullable VoidAction action()
        {
            return action;
        }

        public @Nullable Menu submenu()
        {
            return submenu;
        }

        /** Identifies the shared separator entry. */
        public boolean isSeparator()
        {
            return this == SEPARATOR;
        }

        public static final class Builder
        {
            /* Store the required fields and any optional activation behaviour. */
            private final String id;
            private final String menuKey;
            private final String label;
            private @Nullable String accelerator;
            private @Nullable VoidAction action;
            private @Nullable Menu submenu;

            private Builder(String id, String menuKey, String label)
            {
                if (id == null || menuKey == null || label == null)
                    throw new IllegalArgumentException("A menu item requires an ID, menu key and label");
                this.id = id;
                this.menuKey = menuKey;
                this.label = label;
            }

            /** Sets the default accelerator. */
            public Builder setAccelerator(String accelerator)
            {
                this.accelerator = accelerator;
                return this;
            }

            /** Sets the action invoked when the item is selected. */
            public Builder setAction(VoidAction action)
            {
                if (submenu != null)
                    throw new IllegalStateException("A menu item cannot have both an action and a submenu");
                this.action = action;
                return this;
            }

            /** Sets the submenu opened when the item is selected. */
            public Builder setSubmenu(Menu submenu)
            {
                if (action != null)
                    throw new IllegalStateException("A menu item cannot have both an action and a submenu");
                this.submenu = submenu;
                return this;
            }

            /** Creates an item with the current builder values. */
            public Item build()
            {
                return new Item(label, id, menuKey, accelerator, action, submenu);
            }
        }
    }
}
