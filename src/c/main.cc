/* © 2008 David Given.
 * WordGrinder is licensed under the MIT open source license. See the COPYING
 * file in this distribution for the full text.
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <locale.h>
#include "globals.h"

#include "script_table.h"

#if !defined WIN32
#include <langinfo.h>
#endif

bool enable_unicode;

#if defined WIN32
#include <windows.h>
static void find_exe(void)
{
    char path[MAX_PATH] = "WINDOWS_EXE=";
    const int len = strlen(path);
    GetModuleFileName(NULL, path + len, sizeof(path) - len);
    putenv(path);
}
#endif

int main(int argc, char* argv[])
{
#if defined WIN32
    find_exe();
#endif

    setlocale(LC_ALL, "");
#if defined WIN32
    enable_unicode = true;
#else
    enable_unicode = strcmp(nl_langinfo(CODESET), "UTF-8") == 0;
#endif

    script_init();
    screen_init((const char**)argv);
    word_init();
    utils_init();
    filesystem_init();
    zip_init();
    clipboard_init();

    script_load_from_table(script_table);
    script_run((const char**)argv);

    return 0;
}
