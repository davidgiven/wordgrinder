/* © 2007 David Given.
 * WordGrinder is licensed under the BSD open source license. See the COPYING
 * file in this distribution for the full text.
 *
 * $Id$
 * $URL: $
 */

#include <stdlib.h>
#include <stdio.h>
#include <locale.h>
#include "globals.h"

int main(int argc, const char* argv[])
{
	setlocale(LC_ALL, "");
	setlocale(LC_COLLATE, "C");
	script_init();
	screen_init();
	word_init();
	bit_init();
	
	script_load(LUA_SRC_DIR "main.lua", argv);
	
	return 0;
}
