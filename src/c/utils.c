/* © 2007 David Given.
 * WordGrinder is licensed under the BSD open source license. See the COPYING
 * file in this distribution for the full text.
 *
 * $Id$
 * $URL: $
 */

#include "globals.h"

static const uint32_t offsets[6] = {
    0x00000000UL, 0x00003080UL, 0x000E2080UL,
    0x03C82080UL, 0xFA082080UL, 0x82082080UL
};

static const char trailing_bytes[256] = {
     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  // 0
     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  // 1
     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  // 2
     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  // 3
     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  // 4
     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  // 5
     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  // 6
     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  // 7
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,  // 8
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,  // 9
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,  // A
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,  // B
     1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  // C
     1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  // D
     2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,  // E
     3, 3, 3, 3, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5,  // F
};

int getu8bytes(char c)
{
	return trailing_bytes[(unsigned char) c] + 1;
}

wint_t readu8(const char** srcp)
{
	const char* src = *srcp;
	int nb = trailing_bytes[*(unsigned char*)src];

	wint_t ch = 0;
	switch (nb) {
	    /* these fall through deliberately */
		case 3: ch += (unsigned char)*src++; ch <<= 6;
		case 2: ch += (unsigned char)*src++; ch <<= 6;
		case 1: ch += (unsigned char)*src++; ch <<= 6;
		case 0: ch += (unsigned char)*src++;
	}
	
	ch -= offsets[nb];
	*srcp = src;
	return ch;
}

void writeu8(char** destp, wint_t ch)
{
	char* dest = *destp;
	
    if (ch < 0x80)
    {
        *dest++ = (char)ch;
    }
    else if (ch < 0x800)
    {
        *dest++ = (ch>>6) | 0xC0;
        *dest++ = (ch & 0x3F) | 0x80;
    }
    else if (ch < 0x10000)
    {
        *dest++ = (ch>>12) | 0xE0;
        *dest++ = ((ch>>6) & 0x3F) | 0x80;
        *dest++ = (ch & 0x3F) | 0x80;
    }
    else
    {
        *dest++ = (ch>>18) | 0xF0;
        *dest++ = ((ch>>12) & 0x3F) | 0x80;
        *dest++ = ((ch>>6) & 0x3F) | 0x80;
        *dest++ = (ch & 0x3F) | 0x80;
    }
    
    *destp = dest;
}
