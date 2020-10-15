/* © 2008 David Given.
 * WordGrinder is licensed under the MIT open source license. See the COPYING
 * file in this distribution for the full text.
 */

#include <stdlib.h>
#include <stdio.h>
#include <locale.h>
#include "globals.h"

extern int luaopen_lpeg (lua_State *L);

static void findlocale(void)
{
	static const char* locales[] =
		{
			"C.UTF-8",
			"en_US.UTF-8",
			"en_GB.UTF-8",
			"",
			NULL
		};
	const char** p = locales;

	while (*p)
	{
		if (setlocale(LC_ALL, *p))
			return;
		p++;
	}
}

int main(int argc, const char* argv[])
{
	findlocale();
	script_init();
	screen_init(argv);
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
	script_run(argv);

	return 0;
}
