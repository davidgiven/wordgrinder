package com.cowlark.wordgrinder.nativeinterface;

import org.jspecify.annotations.NonNull;
import org.jspecify.annotations.Nullable;

/**
 * Supplies application paths and process control independently of the runtime backend.
 */
public interface System
{
    /**
     * Returns HOME/.wordgrinder, falling back to USERPROFILE and then the current directory.
     */
    @NonNull String getConfigDirectory();

    /**
     * Returns the Windows executable path, or null on other platforms or when unavailable.
     */
    @Nullable String getExecutablePath();

    /* Terminate with the supplied process exit status. */
    void exit(int status);
}
