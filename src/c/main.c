/* © 2008 David Given.
 * WordGrinder is licensed under the MIT open source license. See the COPYING
 * file in this distribution for the full text.
 */

#include <stdlib.h>
#include <stdio.h>
#include <locale.h>
#include "globals.h"

extern int luaopen_lpeg (lua_State *L);

#if defined WIN32
#include <windows.h>
static void find_exe(void)
{
	char path[MAX_PATH] = "WINDOWS_EXE=";
	const int len = strlen(path);
	GetModuleFileName(NULL, path+len, sizeof(path)-len);
	putenv(path);
}
#endif

int main(int argc, char* argv[])
{
	#if defined WIN32
		find_exe();
	#endif

	setlocale(LC_ALL, "");
	script_init();
	screen_init((const char**) argv);
	word_init();
	utils_init();
	filesystem_init();
	zip_init();
	#if (LUA_VERSION_NUM < 502)
		luaopen_lpeg(L);
	#else
		luaL_requiref(L, "lpeg", luaopen_lpeg, 1);
		lua_pop(L, 1);
	#endif

	script_load_from_table(script_table);
	script_run((const char**) argv);

	return 0;
}
