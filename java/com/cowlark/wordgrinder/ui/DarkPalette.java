/* © 2022 David Given.
 * WordGrinder is licensed under the MIT open source licence. See COPYING.
 */

package com.cowlark.wordgrinder.ui;

import com.cowlark.wordgrinder.nativeinterface.Colour;

import com.google.common.collect.ImmutableMap;
import org.jspecify.annotations.NonNull;

/**
 * The Dark theme from colours.lua.
 */
public final class DarkPalette extends Palette
{
    /* Share the immutable colours used by multiple paragraph styles. */
    private static final @NonNull Colour INK = new Colour(1f, 1f, 1f);
    private static final @NonNull Colour PAPER = new Colour(0.2f, 0.2f, 0.2f);
    private static final @NonNull Colour HEADERFG = new Colour(1f, 1f, 0f);
    private static final @NonNull Colour HEADERBG = new Colour(0.3f, 0.3f, 0.3f);

    /* Supply the shared palette implementation with this theme's definitions. */
    public DarkPalette()
    {
        super(
                "Dark",
                ImmutableMap
                        .<String, Colour>builder()
                        .put("Desktop", new Colour(0.135f, 0.135f, 0.135f))
                        .put("Paper", PAPER)
                        .put("MarkerFG", new Colour(0.100f, 0.500f, 0.500f))
                        .put("StatusbarBG", new Colour(0.140f, 0.220f, 0.400f))
                        .put("StatusbarFG", new Colour(0.800f, 0.700f, 0.200f))
                        .put("MessageBG", new Colour(0.140f, 0.220f, 0.400f))
                        .put("MessageFG", new Colour(0.800f, 0.700f, 0.200f))
                        .put("StyleFG", new Colour(0.500f, 0.500f, 0.500f))
                        .put("ControlFG", new Colour(1.000f, 1.000f, 0.000f))
                        .put("ControlBG", new Colour(0.140f, 0.220f, 0.400f))
                        .put("H1_BG", HEADERBG)
                        .put("H1_FG", HEADERFG)
                        .put("H2_BG", HEADERBG)
                        .put("H2_FG", HEADERFG)
                        .put("H3_BG", PAPER)
                        .put("H3_FG", HEADERFG)
                        .put("H4_BG", PAPER)
                        .put("H4_FG", HEADERFG)
                        .put("LN_BG", PAPER)
                        .put("LN_FG", INK)
                        .put("LB_BG", PAPER)
                        .put("LB_FG", INK)
                        .put("L_BG", PAPER)
                        .put("L_FG", INK)
                        .put("PRE_BG", PAPER)
                        .put("PRE_FG", INK)
                        .put("P_BG", PAPER)
                        .put("P_FG", INK)
                        .put("Q_BG", PAPER)
                        .put("Q_FG", INK)
                        .put("RAW_BG", PAPER)
                        .put("RAW_FG", INK)
                        .put("V_BG", PAPER)
                        .put("V_FG", INK)
                        .buildOrThrow());
    }
}
