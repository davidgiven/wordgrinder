#include "cstring-probe.h"
#include "display.h"
#include "clipboard.h"
#include <assert.h>
#include <string.h>
#include <locale.h>
#include <stdlib.h>
#if defined(_WIN32) || defined(WIN32)
#include <windows.h>
#endif

/* Make the native string encoding reproducible rather than inheriting the host locale. */
void wg_cstring_test_init(void)
{
#ifdef _WIN32
    assert(setlocale(LC_CTYPE, ".UTF8") != NULL);
#else
    assert(setlocale(LC_CTYPE, "C.UTF-8") != NULL);
#endif
}

/* Check native encoding and termination, including bytes following an embedded NUL. */
void wg_cstring_test_check(const char* text, int example)
{
    static const char* expected[] = {"", "ASCII", "caf\xc3\xa9 \xf0\x9f\x98\x80", "before\0after"};
    size_t length = example == 3 ? 12 : strlen(expected[example]);
    assert(text != NULL);
    assert(memcmp(text, expected[example], length) == 0);
    assert(text[length] == '\0');
}

/* Verify that every argument remains alive and that the vector has its own terminator. */
void wg_dpy_init(const char* const* argv)
{
    static int calls;
    if (calls++ == 0)
    {
        assert(strcmp(argv[0], "--demo") == 0);
        assert(strcmp(argv[1], "caf\xc3\xa9 \xf0\x9f\x98\x80") == 0);
        assert(strcmp(argv[2], "") == 0);
        assert(argv[3] == NULL);
    }
    else
        assert(argv[0] == NULL);
}

/* The clipboard fixture needs no platform clipboard initialisation. */
void wg_clipboard_init(void) {}

/* Preserve explicit lengths, embedded NULs, binary data and missing/empty formats. */
void wg_clipboard_set(const char* text, int32_t text_length, const char* data, int32_t data_length)
{
    static int calls;
    static const char expected[] = "before\0after \xf0\x9f\x98\x80";
    if (calls == 0)
    {
        assert(text_length == sizeof(expected) - 1);
        assert(memcmp(text, expected, text_length) == 0);
        assert(data_length == 3);
        assert(data[0] == 0 && data[1] == 1 && (unsigned char)data[2] == 255);
    }
    else if (calls == 1)
    {
        assert(text == NULL && text_length == -1);
        assert(data == NULL && data_length == -1);
    }
    else
    {
        assert(text != NULL && text_length == 0);
        assert(text[0] == '\0');
        assert(data_length == 0);
    }
    calls++;
}

/* Check OS discovery and ensure the inherited environment value remains untouched. */
void wg_cstring_test_executable_path(const char* path)
{
    const char* inherited = getenv("WINDOWS_EXE");
    assert(inherited != NULL && strcmp(inherited, "not-the-executable") == 0);
#if defined(_WIN32) || defined(WIN32)
    char expected[MAX_PATH];
    DWORD length = GetModuleFileNameA(NULL, expected, MAX_PATH);
    assert(length > 0 && length < MAX_PATH);
    assert(path != NULL && strcmp(path, expected) == 0);
#else
    assert(path == NULL);
#endif
}
