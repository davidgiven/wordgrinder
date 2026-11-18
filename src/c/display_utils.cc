/* Shared display helpers, independent of the Lua UI. */
#include "globals.h"

void writeu8(char** destp, uni_t ch)
{
    char* dest = *destp;

    if (ch < 0)
        assert(false);
    else if (ch < 0x80)
    {
        *dest++ = (char)ch;
    }
    else if (ch < 0x800)
    {
        *dest++ = (ch >> 6) | 0xC0;
        *dest++ = (ch & 0x3F) | 0x80;
    }
    else if (ch < 0x10000)
    {
        *dest++ = (ch >> 12) | 0xE0;
        *dest++ = ((ch >> 6) & 0x3F) | 0x80;
        *dest++ = (ch & 0x3F) | 0x80;
    }
    else if (ch < 0x200000)
    {
        *dest++ = (ch >> 18) | 0xF0;
        *dest++ = ((ch >> 12) & 0x3F) | 0x80;
        *dest++ = ((ch >> 6) & 0x3F) | 0x80;
        *dest++ = (ch & 0x3F) | 0x80;
    }
    else if (ch < 0x4000000)
    {
        *dest++ = (ch >> 24) | 0xF8;
        *dest++ = ((ch >> 18) & 0x3F) | 0x80;
        *dest++ = ((ch >> 12) & 0x3F) | 0x80;
        *dest++ = ((ch >> 6) & 0x3F) | 0x80;
        *dest++ = (ch & 0x3F) | 0x80;
    }
    else if (ch <= 0x7fffffff)
    {
        *dest++ = (ch >> 30) | 0xFC;
        *dest++ = ((ch >> 24) & 0x3F) | 0x80;
        *dest++ = ((ch >> 18) & 0x3F) | 0x80;
        *dest++ = ((ch >> 12) & 0x3F) | 0x80;
        *dest++ = ((ch >> 6) & 0x3F) | 0x80;
        *dest++ = (ch & 0x3F) | 0x80;
    }

    *destp = dest;
}

uni_t encode_mouse_event(int x, int y, bool b)
{
    uni_t key = b ? KEY_MOUSEDOWN : KEY_MOUSEUP;
    key |= (x & 0xff);
    key |= (y & 0xff) << 8;
    return key;
}
