/* © 2022 David Given.
 * WordGrinder is licensed under the MIT open source licence. See COPYING.
 */

package com.cowlark.wordgrinder.ui;

import static com.google.common.collect.ImmutableMap.toImmutableMap;

import com.cowlark.wordgrinder.nativeinterface.Colour;
import com.google.common.collect.ImmutableList;
import com.google.common.collect.ImmutableMap;
import com.google.common.collect.ImmutableSet;
import org.jspecify.annotations.Nullable;

/**
 * Named colours supplied by a UI theme.
 */
public abstract class Palette
{
    /* Retain each theme's immutable name and colour definitions. */
    private final String name;
    private final ImmutableMap<String, Colour> colours;

    protected Palette(String name, ImmutableMap<String, Colour> colours)
    {
        this.name = name;
        this.colours = colours;
    }

    /**
     * Fetches all themes.
     */
    public static ImmutableSet<String> getThemes()
    {
        return Registry.PALETTES.keySet();
    }

    /**
     * Fetches a named theme.
     */
    public static @Nullable Palette getTheme(String name)
    {
        return Registry.PALETTES.get(name);
    }

    /**
     * Returns the palette name.
     */
    public final String getName()
    {
        return name;
    }

    /**
     * Looks up a colour name, returning null if it is absent.
     */
    public final @Nullable Colour getColour(String colour)
    {
        return colours.get(colour);
    }

    /* Initialise the registry lazily so subclass colour maps are ready before construction. */
    private static final class Registry
    {
        private static final ImmutableMap<String, Palette> PALETTES = ImmutableList
                .of(new ClassicPalette(), new DarkPalette(), new LightPalette())
                .stream()
                .collect(toImmutableMap(p -> p.getName(), p -> p));
    }
}
