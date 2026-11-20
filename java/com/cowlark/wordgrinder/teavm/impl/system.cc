#include "system.h"
#include <cstddef>

#if defined(_WIN32) || defined(WIN32)
#include <windows.h>

/* Keep the returned buffer alive until Java has copied the path. */
static char executablePath[MAX_PATH];
#endif

/* Discover the executable directly, without using the process environment. */
char* wg_system_get_executable_path(void)
{
#if defined(_WIN32) || defined(WIN32)
    DWORD length = GetModuleFileNameA(NULL, executablePath, MAX_PATH);
    if (length == 0 || length >= MAX_PATH)
        return NULL;
    executablePath[length] = '\0';
    return executablePath;
#else
    return NULL;
#endif
}
