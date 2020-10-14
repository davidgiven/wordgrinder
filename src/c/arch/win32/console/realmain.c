/* © 2020 David Given.
 * WordGrinder is licensed under the MIT open source license. See the COPYING
 * file in this distribution for the full text.
 */

#include "globals.h"
#include <stdlib.h>
#include <string.h>
#include <windows.h>

#undef main
extern int appMain(int argc, const char* argv[]);

static void find_exe(void)
{
	char path[MAX_PATH] = "WINDOWS_EXE=";
	const int len = strlen(path);
	GetModuleFileName(NULL, path+len, sizeof(path)-len);
	putenv(path);
}

int main(int argc, const char* argv[])
{
	find_exe();
	return appMain(argc, argv);
}

