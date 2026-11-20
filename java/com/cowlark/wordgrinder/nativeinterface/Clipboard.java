/* © 2026 David Given.
 * WordGrinder is licensed under the MIT open source licence. See COPYING.
 */

package com.cowlark.wordgrinder.nativeinterface;

import org.jspecify.annotations.NonNull;
import org.jspecify.annotations.Nullable;

/**
 * Backend-independent clipboard operations.
 */
public interface Clipboard
{
    /* Operations are supplied by an injected backend instance. */
    void clipboardInit();

    void clipboardClear();

    @NonNull Contents clipboardGet();

    void clipboardSet(@Nullable String text, byte @Nullable [] wordgrinderData);

    /* A missing format is null; an available format may be empty. */
    record Contents(@Nullable String text, byte @Nullable [] wordgrinderData)
    {
    }
}
