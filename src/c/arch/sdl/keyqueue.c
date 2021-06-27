/* © 2021 David Given.
 * WordGrinder is licensed under the MIT open source license. See the COPYING
 * file in this distribution for the full text.
 */

#include "globals.h"
#include <string.h>
#include "keyqueue.h"

static uni_t* buffer0 = NULL;
static uni_t* buffer1 = NULL;
static unsigned buffer0_size = 0; /* power of two */
static unsigned buffer1_size = 0; /* power of two */
static unsigned buffer0_ptr = 0;
static unsigned buffer1_ptr = 0;

uni_t get_queued_key(void)
{
	if (!buffer1)
		return 0;
	if (buffer1_ptr == 0)
	{
		/* buffer1 is empty; move everything from buffer0 to buffer1. */

		while (buffer0_ptr)
		{
			if (buffer1_ptr == buffer1_size)
			{
				buffer1_size *= 2;
				buffer1 = realloc(buffer1, buffer1_size * sizeof(uni_t));
			}

			buffer1[buffer1_ptr++] = buffer0[--buffer0_ptr];
		}
	}
	if (buffer1_ptr == 0)
		return 0;

	return buffer1[--buffer1_ptr];
}

void put_queued_key(uni_t k)
{
	if (!buffer0)
	{
		buffer0_size = buffer1_size = 32;
		buffer0 = calloc(sizeof(uni_t), buffer0_size);
		buffer1 = calloc(sizeof(uni_t), buffer1_size);
		buffer0_ptr = buffer1_ptr = 0;
	}

	if (buffer0_ptr == buffer0_size)
	{
		buffer0_size *= 2;
		buffer0 = realloc(buffer0, buffer0_size * sizeof(uni_t));
	}
	buffer0[buffer0_ptr++] = k;
}

