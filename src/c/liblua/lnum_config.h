/*
** $Id$
** Internal Number model
** See Copyright Notice in lua.h
*/

#ifndef lnum_config_h
#define lnum_config_h


#ifdef LNUM_COMPLEX
# if __STDC_VERSION__ < 199901L
#  error "Need C99 for complex (use '--std=c99' or similar)"
# endif
    /* Code in at least 'lvm.c' and 'liolib.c' relies on COMPLEX to always 
    * have integer optimization. */
# if !((defined LNUM_INT32) || (defined LNUM_INT64)) 
#  error "Please #define either LNUM_INT32 or LNUM_INT64 together with LNUM_COMPLEX"
# endif
#endif

#if (!defined LNUM_FLOAT) && (!defined LNUM_LDOUBLE) && (!defined LNUM_DOUBLE)
# define LNUM_DOUBLE
#endif
#if (defined LUA_USELONGLONG) && (!defined LNUM_INT64)
# define LNUM_INT64
#endif

/*
** Number mode identifier to accompany the version string.
*/
#ifdef LNUM_COMPLEX
# define _LNUM1 "complex "
#else
# define _LNUM1 ""
#endif
#ifdef LNUM_FLOAT
# define _LNUM2 "float"
#elif defined(LNUM_LDOUBLE)
# define _LNUM2 "long double"
#else
# define _LNUM2 "double"
#endif
#ifdef LNUM_INT32
# define _LNUM3 " int32"
#elif defined(LNUM_INT64)
# define _LNUM3 " int64"
#else
# define _LNUM3 ""
#endif
#define LUA_LNUM _LNUM1 _LNUM2 _LNUM3

/*
** LUA_NUMBER is the type of floating point number in Lua
** LUA_NUMBER_SCAN is the format for reading numbers.
** LUA_NUMBER_FMT is the format for writing numbers.
*/
#ifdef LNUM_FLOAT
# define LUA_NUMBER         float
# define LUA_NUMBER_SCAN    "%f"
# define LUA_NUMBER_FMT     "%g"  
#elif (defined LNUM_LDOUBLE)
# define LUA_NUMBER         long double
# define LUA_NUMBER_SCAN    "%Lg"
# define LUA_NUMBER_FMT     "%.14Lg"  
#else
# define LUA_NUMBER	        double
# define LUA_NUMBER_SCAN    "%lf"
# define LUA_NUMBER_FMT     "%.14g"
#endif


/* 
** LUAI_MAXNUMBER2STR: size of a buffer fitting any number->string result.
**
**  normal:  24 (sign, x.xxxxxxxxxxxxxxe+nnnn, and \0)
**  int64:   21 (19 digits, sign, and \0)
**  complex: twice anything ('i' instead of the other \0)
**  long double: 25 Currently limited to normal range by "%.14Lg" above
**               (extend here if that relaxed), but exponent has 15 bits on x86
**               (nnnnn).
*/
#ifndef LNUM_COMPLEX
# define LUAI_MAXNUMBER2STR 25
#else
# define LUAI_MAXNUMBER2STR 50
#endif

/*
** LUA_INTEGER is the integer type used by lua_pushinteger/lua_tointeger/lua_isinteger.
** It needs to be defined even if only-floating point number modes were used.
** LUA_INTFRMLEN is the length modifier for integer conversions in 'string.format'.
** LUA_INTFRM_T is the integer type correspoding to the previous length modifier.
**
** Note: Visual C++ 2005 does not have 'strtoull()', use '_strtoui64()' instead.
*/
#ifdef LNUM_INT64
# define LUA_INTEGER	long long
# ifdef _MSC_VER
#  define lua_str2ul    _strtoui64
# else
#  define lua_str2ul    strtoull
# endif
# define lua_str2ul_t   unsigned long long
# define LUA_INTFRMLEN	"ll"
# define LUA_INTFRM_T	long long
# define LUA_INTEGER_MAX 0x7fffffffffffffffLL       /* 2^63-1 */ 
# define LUA_INTEGER_MIN (-LUA_INTEGER_MAX - 1LL)   /* -2^63 */
#else
/* On most machines, ptrdiff_t gives a good choice between int or long. */
# define LUA_INTEGER    ptrdiff_t
# define lua_str2ul     strtoul
# define lua_str2ul_t   unsigned  /* 'unsigned ptrdiff_t' is invalid */
# define LUA_INTFRMLEN	"l"
# define LUA_INTFRM_T	long
# define LUA_INTEGER_MAX 0x7FFFFFFF             /* 2^31-1 */
# define LUA_INTEGER_MIN (-LUA_INTEGER_MAX -1)  /* -2^31 */
#endif


/*
@@ lua_number2int is a macro to convert lua_Number to int.
@@ lua_number2integer is a macro to convert lua_Number to lua_Integer.
** CHANGE them if you know a faster way to convert a lua_Number to
** int (with any rounding method and without throwing errors) in your
** system. In Pentium machines, a naive typecast from double to int
** in C is extremely slow, so any alternative is worth trying.
*/

/* On a Pentium, resort to a trick */
#if (!defined(LNUM_FLOAT) && !defined(LNUM_LDOUBLE)) && \
    !defined(LUA_ANSI) && !defined(__SSE2__) && \
    (defined(__i386) || defined (_M_IX86) || defined(__i386__))

/* On a Microsoft compiler, use assembler */
# if defined(_MSC_VER)
#  define lua_number2int(i,d)   __asm fld d   __asm fistp i
# else

/* the next trick should work on any Pentium, but sometimes clashes
   with a DirectX idiosyncrasy */
union luai_Cast { double l_d; long l_l; };
#  define lua_number2int(i,d) \
  { volatile union luai_Cast u; u.l_d = (d) + 6755399441055744.0; (i) = u.l_l; }
# endif

# ifndef LNUM_INT64
#  define lua_number2integer    lua_number2int
# endif

/* this option always works, but may be slow */
#else
# define lua_number2int(i,d)        ((i)=(int)(d))
#endif

/* TBD: the following line may be compiler specific, and is controversial. Some compilers
 *      (OS X gcc 4.0?) may choke on double->long long conversion (since it can lose
 *      precision; double does not have 63-bit mantissa). Others do require 'long long'
 *      there.  TO BE TESTED ON MULTIPLE SYSTEMS, AND COMPILERS.  -- AKa 12-Oct-06
 */
#ifndef lua_number2integer
# define lua_number2integer(i,d)    ((i)=(lua_Integer)(d))
#endif


/*
** LUAI_UACNUMBER is the result of an 'usual argument conversion' over a number.
** LUAI_UACINTEGER the same, over an integer.
*/
#define LUAI_UACNUMBER	double

/* TBD: lua_sprintf("%d",v) has problems in 64 bit operation; can this solve them?
*/
#define LUAI_UACINTEGER LUA_INTFRM_T


#endif

