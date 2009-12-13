/* © 2008 David Given.
 * WordGrinder is licensed under the MIT open source license. See the COPYING
 * file in this distribution for the full text.
 *
 * $Id$
 * $URL$
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
	screen_init(argv);
	word_init();
	bit_init();
	utils_init();

	script_load_from_table(script_table);
	script_run(argv);

	return 0;
}
