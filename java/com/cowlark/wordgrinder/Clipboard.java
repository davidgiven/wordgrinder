package com.cowlark.wordgrinder;

import org.teavm.interop.Address;
import org.teavm.interop.Import;
import org.teavm.interop.c.Include;
import java.nio.charset.StandardCharsets;

/**
 * Java equivalents of src/c/clipboard.cc, using the native clip backend.
 */
@Include("clipboard.h")
public final class Clipboard
{
    private static boolean initialized;

    private Clipboard()
    {
    }

    public static void clipboardInit()
    {
        if (!initialized)
        {
            initNative();
            initialized = true;
        }
    }

    public static void clipboardClear()
    {
        clipboardInit();
        clearNative();
    }

    public static Contents clipboardGet()
    {
        clipboardInit();
        Address snapshot = getNative();
        if (snapshot == null)
            throw new OutOfMemoryError();
        try
        {
            byte[] text = read(snapshot, 0);
            return new Contents(
                    text == null ? null : new String(text, StandardCharsets.UTF_8),
                    read(snapshot, 1));
        } finally
        {
            releaseNative(snapshot);
        }
    }

    /**
     * Replaces the clipboard; null omits a format, while an empty value stores it.
     */
    public static void clipboardSet(String text, byte[] wordgrinderData)
    {
        clipboardInit();
        byte[] encoded = text == null ? null : text.getBytes(StandardCharsets.UTF_8);
        setNative(
                encoded == null ? null : Address.ofData(encoded),
                encoded == null ? -1 : encoded.length,
                wordgrinderData == null ? null : Address.ofData(wordgrinderData),
                wordgrinderData == null ? -1 : wordgrinderData.length);
        Address.pin(encoded);
        Address.pin(wordgrinderData);
    }

    private static byte[] read(Address snapshot, int format)
    {
        int length = lengthNative(snapshot, format);
        if (length < 0)
            return null;
        byte[] bytes = new byte[length];
        Address source = dataNative(snapshot, format);
        for (int i = 0; i < length; i++)
            bytes[i] = source
                    .add(i).getByte();
        return bytes;
    }

    @Import(name = "wg_clipboard_init")
    private static native void initNative();

    @Import(name = "wg_clipboard_clear")
    private static native void clearNative();

    @Import(name = "wg_clipboard_get")
    private static native Address getNative();

    @Import(name = "wg_clipboard_length")
    private static native int lengthNative(Address snapshot, int format);

    @Import(name = "wg_clipboard_data")
    private static native Address dataNative(Address snapshot, int format);

    @Import(name = "wg_clipboard_release")
    private static native void releaseNative(Address snapshot);

    @Import(name = "wg_clipboard_set")
    private static native void setNative(
            Address text,
            int textLength,
            Address data,
            int dataLength);

    /**
     * Either field is null when its clipboard format is unavailable.
     */
    public record Contents(String text, byte[] wordgrinderData)
    {
    }
}
