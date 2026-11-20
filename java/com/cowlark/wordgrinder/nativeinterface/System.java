package com.cowlark.wordgrinder.nativeinterface;

/**
 * Controls application termination independently of the runtime backend.
 */
public interface System
{
    /* Terminate with the supplied process exit status. */
    void exit(int status);
}
