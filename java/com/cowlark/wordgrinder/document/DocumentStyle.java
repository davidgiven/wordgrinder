/* © 2008 David Given.
 * WordGrinder is licensed under the MIT open source license. See the COPYING
 * file in this distribution for the full text.
 */

package com.cowlark.wordgrinder.document;

import static com.cowlark.wordgrinder.nativeinterface.Display.DPY_BOLD;
import static com.cowlark.wordgrinder.nativeinterface.Display.DPY_BRIGHT;
import static com.cowlark.wordgrinder.nativeinterface.Display.DPY_ITALIC;
import static com.cowlark.wordgrinder.nativeinterface.Display.DPY_UNDERLINE;

import org.jspecify.annotations.Nullable;

/**
 * Paragraph layout and list settings, corresponding to DocumentStyle in document.lua.
 * A missing first-line indent inherits the ordinary indent. An explicit zero
 * overrides it.
 *
 * @param desc        human-readable style description
 * @param name        style identifier, such as P or H1
 * @param above       number of blank lines requested above the paragraph
 * @param below       number of blank lines requested below the paragraph
 * @param indent      indentation of subsequent lines, defaulting to zero
 * @param bullet      bullet text, or null for no bullet
 * @param list        whether the style belongs to a list
 * @param firstIndent first-line indentation, or null to inherit indent
 * @param numbered    whether the list is numbered
 * @param nextStyle   style for a following paragraph, or null to retain this style
 * @param cstyle      precomputed display attributes applied to every word
 */
public record DocumentStyle(String desc, String name, int above, int below,
                            int indent, @Nullable String bullet,
                            boolean list, @Nullable Integer firstIndent,
                            boolean numbered, @Nullable String nextStyle, int cstyle)
{
    /* Precompute the Lua heading markup once when constructing a named style. */
    public DocumentStyle(
            String desc,
            String name,
            int above,
            int below,
            int indent,
            @Nullable String bullet,
            boolean list,
            @Nullable Integer firstIndent,
            boolean numbered,
            @Nullable String nextStyle)
    {
        this(
                desc,
                name,
                above,
                below,
                indent,
                bullet,
                list,
                firstIndent,
                numbered,
                nextStyle,
                switch (name)
                {
                    case "H1" -> DPY_ITALIC | DPY_BRIGHT | DPY_BOLD | DPY_UNDERLINE;
                    case "H2" -> DPY_BRIGHT | DPY_BOLD | DPY_UNDERLINE;
                    case "H3" -> DPY_ITALIC | DPY_BRIGHT | DPY_BOLD;
                    case "H4" -> DPY_BRIGHT | DPY_BOLD;
                    default -> 0;
                });
    }
}
