package com.cowlark.wordgrinder.teavm.impl;

import org.jspecify.annotations.Nullable;
import org.teavm.backend.c.runtime.Memory;
import org.teavm.interop.Address;
import org.teavm.interop.Strings;

/**
 * Owns a null-terminated string allocated in the C runtime's character encoding.
 */
final class CString implements AutoCloseable
{
    /* Keep the allocation alive until the native call has finished. */
    private final Address address;

    CString(String string)
    {
        address = Strings.toC(string);
        if (address == null)
            throw new OutOfMemoryError();
    }

    /**
     * Copies a C string, returning null for a null pointer.
     */
    public static @Nullable String fromC(@Nullable Address address)
    {
        if (address == null)
            return null;
        return Strings.fromC(address);
    }

    /* Release the C allocation when leaving the owning resource scope. */
    @Override
    public void close()
    {
        Memory.free(address);
    }

    /**
     * Returns the pointer while this resource is open.
     */
    public Address getAddress()
    {
        return address;
    }
}
