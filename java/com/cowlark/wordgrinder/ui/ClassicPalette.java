/* © 2022 David Given.
 * WordGrinder is licensed under the MIT open source licence. See COPYING.
 */

package com.cowlark.wordgrinder.ui;

import com.cowlark.wordgrinder.nativeinterface.Colour;

import com.google.common.collect.ImmutableMap;

/**
 * The Classic theme from colours.lua.
 */
public final class ClassicPalette extends Palette
{
    /* Share the immutable colours used by multiple paragraph styles. */
    private static final Colour INK = new Colour(0.8f, 0.8f, 0.8f);
    private static final Colour WHITE = new Colour(1f, 1f, 1f);
    private static final Colour BLACK = new Colour(0f, 0f, 0f);
    private static final Colour YELLOW = new Colour(1f, 1f, 0f);

    /* Supply the shared palette implementation with this theme's definitions. */
    public ClassicPalette()
    {
        super(
                "Classic",
                ImmutableMap
                        .<String, Colour>builder()
                        .put("Desktop", BLACK)
                        .put("Paper", BLACK)
                        .put("MarkerFG", WHITE)
                        .put("StatusbarFG", BLACK)
                        .put("StatusbarBG", WHITE)
                        .put("MessageFG", BLACK)
                        .put("MessageBG", WHITE)
                        .put("StyleFG", new Colour(0.500f, 0.500f, 0.500f))
                        .put("ControlFG", WHITE)
                        .put("ControlBG", BLACK)
                        .put("H1_BG", BLACK)
                        .put("H1_FG", YELLOW)
                        .put("H2_BG", BLACK)
                        .put("H2_FG", YELLOW)
                        .put("H3_BG", BLACK)
                        .put("H3_FG", YELLOW)
                        .put("H4_BG", BLACK)
                        .put("H4_FG", YELLOW)
                        .put("LN_BG", BLACK)
                        .put("LN_FG", INK)
                        .put("LB_BG", BLACK)
                        .put("LB_FG", INK)
                        .put("L_BG", BLACK)
                        .put("L_FG", INK)
                        .put("PRE_BG", BLACK)
                        .put("PRE_FG", INK)
                        .put("P_BG", BLACK)
                        .put("P_FG", INK)
                        .put("Q_BG", BLACK)
                        .put("Q_FG", INK)
                        .put("RAW_BG", BLACK)
                        .put("RAW_FG", INK)
                        .put("V_BG", BLACK)
                        .put("V_FG", INK)
                        .buildOrThrow());
    }
}
