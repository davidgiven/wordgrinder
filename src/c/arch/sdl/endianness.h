#ifndef ENDIANNESS_H
#define ENDIANNESS_H

#if defined(WIN32)
	#define IS_LITTLE_ENDIAN
#endif

#if defined(__FreeBSD__) || defined(__NetBSD__) || defined(__OpenBSD__) || defined(__DragonflyBSD__)
	#include <sys/endian.h>

	#if _BYTE_ORDER == _BIG_ENDIAN
		#define IS_BIG_ENDIAN
	#elif _BYTE_ORDER == _LITTLE_ENDIAN
		#define IS_LITTLE_ENDIAN
	#endif
#endif

/* OSX has __BIG_ENDIAN__ or __LITTLE_ENDIAN__ set automatically by the compiler. */

#if defined(__APPLE__) && defined(__MACH__) || defined(__ellcc__ )
	#if defined(__BIG_ENDIAN__) && __BIG_ENDIAN__
		#define IS_BIG_ENDIAN
	#endif

	#if defined(__LITTLE_ENDIAN__) && __LITTLE_ENDIAN__
		#define IS_LITTLE_ENDIAN
	#endif
#endif

#if defined(__linux__)
	#include <endian.h>

	#if __BYTE_ORDER == __BIG_ENDIAN
		#define IS_BIG_ENDIAN
	#elif __BYTE_ORDER == __LITTLE_ENDIAN
		#define IS_LITTLE_ENDIAN
	#endif
#endif

#if !defined(IS_BIG_ENDIAN) && !defined(IS_LITTLE_ENDIAN)
	#error Could not determine endianness.
#endif

#endif

