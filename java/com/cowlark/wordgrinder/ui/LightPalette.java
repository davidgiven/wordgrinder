/* © 2022 David Given.
 * WordGrinder is licensed under the MIT open source licence. See COPYING.
 */

package com.cowlark.wordgrinder.ui;

import com.cowlark.wordgrinder.nativeinterface.Colour;

import com.google.common.collect.ImmutableMap;

/**
 * The Light theme from colours.lua.
 */
public final class LightPalette extends Palette
{
    /* Share the immutable colours used by multiple paragraph styles. */
    private static final Colour INK = new Colour(0f, 0f, 0f);
    private static final Colour PAPER = new Colour(0.760f, 0.760f, 0.730f);
    private static final Colour HEADERFG = new Colour(0.14f, 0.22f, 0.40f);
    private static final Colour HEADERBG = new Colour(0.66f, 0.66f, 0.66f);

    /* Supply the shared palette implementation with this theme's definitions. */
    public LightPalette()
    {
        super(
                "Light",
                ImmutableMap
                        .<String, Colour>builder()
                        .put("Desktop", new Colour(0.510f, 0.500f, 0.470f))
                        .put("Paper", PAPER)
                        .put("MarkerFG", new Colour(0.250f, 0.250f, 0.250f))
                        .put("StatusbarBG", new Colour(0.140f, 0.220f, 0.400f))
                        .put("StatusbarFG", new Colour(0.800f, 0.700f, 0.200f))
                        .put("MessageBG", new Colour(0.140f, 0.220f, 0.400f))
                        .put("MessageFG", new Colour(0.800f, 0.700f, 0.200f))
                        .put("StyleFG", new Colour(0.200f, 0.200f, 0.200f))
                        .put("ControlFG", new Colour(0.200f, 0.200f, 0.200f))
                        .put("ControlBG", new Colour(0.850f, 0.850f, 0.850f))
                        .put("H1_BG", HEADERBG)
                        .put("H1_FG", HEADERFG)
                        .put("H2_BG", HEADERBG)
                        .put("H2_FG", HEADERFG)
                        .put("H3_BG", PAPER)
                        .put("H3_FG", INK)
                        .put("H4_BG", PAPER)
                        .put("H4_FG", INK)
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
