/*
** $Id$
** Internal Number model - pure double or: int32|64 + float/double
** Copyright ...
*/

#include <stdlib.h>
#include <math.h>
#include <ctype.h>
#include <string.h>
#include <stdio.h>

#define lnum_c
#define LUA_CORE

#include "lua.h"
#include "llex.h"
#include "lnum.h"

/*
** lua_real2str converts a (non-complex) number to a string.
** lua_str2real converts a string to a (non-complex) number.
** LUAI_MAXNUMBER2STR is size of buffer needed for the above.
*/
#define lua_real2str(s,n)	sprintf((s), LUA_NUMBER_FMT, (n))
#define lua_str2real(s,p)	strtod((s), (p))

#define lua_integer2str(s,v) \
    sprintf((s), "%" LUA_INTFRMLEN "d", (LUA_INTFRM_T) (v))

/* 's' is expected to be LUAI_MAXNUMBER2STR long (enough for any number)
*/
lu_bool luaO_num2buf( char *s, const TValue *o )
{
  lua_Number n;

  if (!ttisnumber(o)) return 0;

  /* Reason to handle integers differently is not only speed,
     but accuracy as well. We want to make any integer tostring()
     without roundings, at all.
  */
#ifdef LUA_TINT
  if (ttisinteger(o)) {
    lua_integer2str( s, ivalue(o) );
    return 1;
  }
  n= nvalue_fast(o);
#else
  n= nvalue(o);
#endif
  lua_real2str(s, n);

#ifdef LNUM_COMPLEX
  lua_Number n2= nvalue_img_fast(o);
  if (n2!=0) {   /* Postfix with +-Ni */
      lu_bool re0= (n == 0);
      char *s2= re0 ? s : strchr(s,'\0'); 
      lua_assert(s2);
      if ((!re0) && (n2>0)) *s2++= '+';
      lua_real2str( s2, n2 );
      strcat(s2,"i");
  }
#endif
  return 1;
}

/* Note: Regular Lua (using 'strtod()') allow 0x+hex but not 0+octal.
 *       'strtoul[l]()' functions allow both if using the "autobase" 0.
 *
 * Full hex range (0 .. 0xffff..) is stored as integers, not to lose any bits.
 * Numerically, 0xffff.. will be -1, just be aware of this! Dec values are
 * taken only for the signed range (rest handled as floating point, and may
 * lose accuracy).
 */
static lu_bool luaO_str2i (const char *s, lua_Integer *res) {
  char *endptr;
  lua_str2ul_t v= lua_str2ul(s, &endptr, 10);
  if (endptr == s) return 0;  /* conversion failed */
  if (v==0 && *endptr=='x')
    v= lua_str2ul(s, &endptr, 16);  /* retry, as hex */
  else if (v > LUA_INTEGER_MAX) 
	return 0;	/* does not fit in signed range */

  if (*endptr != '\0') {
    while (isspace(cast(unsigned char, *endptr))) endptr++;
    if (*endptr != '\0') return 0;  /* invalid trail */
  }
  *res= (lua_Integer)v;
  return 1;
}

/* 0 / TK_NUMBER / TK_INT (/ TK_NUMBER2) */
int luaO_str2d (const char *s, lua_Number *result, lua_Integer *res2) {
  char *endptr;
  int ret= TK_NUMBER;
  /* Check integers first, if caller is allowing. If 'res2'==NULL,
   * we know they're only looking for floating point. */
  if (res2 && luaO_str2i(s,res2))
    return TK_INT;
  *result = lua_str2real(s, &endptr);
  if (endptr == s) return 0;  /* conversion failed */
#ifdef LNUM_COMPLEX
  if (*endptr == 'i') { endptr++; ret= TK_NUMBER2; }
#endif
  if (*endptr == '\0') return ret;  /* most common case */
  while (isspace(cast(unsigned char, *endptr))) endptr++;
  if (*endptr != '\0') return 0;  /* invalid trailing characters? */
  return ret;
}


/* Functions for finding out, when integer operations remain in range
 * (and doing them).
 */
lu_bool try_addint( lua_Integer *r, lua_Integer ib, lua_Integer ic ) {
  lua_Integer v= ib+ic; /* may overflow */
  if (ib>0 && ic>0)      { if (v < 0) return 0; /*overflow, use floats*/ }
  else if (ib<0 && ic<0) { if (v >= 0) return 0; }
  *r= v;
  return 1;
}

lu_bool try_subint( lua_Integer *r, lua_Integer ib, lua_Integer ic ) {
  lua_Integer v= ib-ic; /* may overflow */
  if (ib>=0 && ic<0)     { if (v < 0) return 0; /*overflow, use floats*/ }
  else if (ib<0 && ic>0) { if (v >= 0) return 0; }
  *r= v;
  return 1;
}

lu_bool try_mulint( lua_Integer *r, lua_Integer ib, lua_Integer ic ) {
  /* If either is -2^31, multiply with anything but 0,1 would be out or range.
   * 0,1 will go through the float route, but will fall back to integers
   * eventually (no accuracy lost, so no need to check).
   * Also, anything causing -2^31 result (s.a. -2*2^30) will take the float
   * route, but later fall back to integer without accuracy loss. :)
   */
  if (ib!=LUA_INTEGER_MIN && ic!=LUA_INTEGER_MIN) {
    lua_Integer b= abs(ib), c= abs(ic);
    if ( (ib==0) || (LUA_INTEGER_MAX/b > c) ||
                   ((LUA_INTEGER_MAX/b == c) && (LUA_INTEGER_MAX%b == 0)) ) {
      *r= ib*ic;  /* no overflow */
      return 1;
    }
  }
  return 0;
}

lu_bool try_divint( lua_Integer *r, lua_Integer ib, lua_Integer ic ) {
  /* -2^31/N: leave to float side (either the division causes non-integer results,
   *          or fallback to integer through float calculation, but without accuracy
   *          lost (N=2,4,8,..,256 and N=2^30,2^29,..2^23).
   * N/-2^31: leave to float side (always non-integer results or 0 or +1)
   * N/0:     leave to float side, to give an error
   *
   * Note: We _can_ use ANSI C mod here, even on negative values, since
   *       we only test for == 0 (the sign would be implementation dependent).
   */
  if (ic!=0 && ib!=LUA_INTEGER_MIN && ic!=LUA_INTEGER_MIN) {
    if (ib%ic == 0) { *r= ib/ic; return 1; }
  }
  return 0;
}

lu_bool try_modint( lua_Integer *r, lua_Integer ib, lua_Integer ic ) {
  if (ic!=0) {
    /* ANSI C can be trusted when b%c==0, or when values are non-negative. 
     * b - (floor(b/c) * c)
     *   -->
     * + +: b - (b/c) * c (b % c can be used)
     * - -: b - (b/c) * c (b % c could work, but not defined by ANSI C)
     * 0 -: b - (b/c) * c (=0, b % c could work, but not defined by ANSI C)
     * - +: b - (b/c-1) * c (when b!=-c)
     * + -: b - (b/c-1) * c (when b!=-c)
     *
     * o MIN%MIN ends up 0, via overflow in calcs but that does not matter.
     * o MIN%MAX ends up MAX-1 (and other such numbers), also after overflow,
     *   but that does not matter, results do.
     */
    lua_Integer v= ib % ic;
    if ( v!=0 && (ib<0 || ic<0) ) {
      v= ib - ((ib/ic) - ((ib<=0 && ic<0) ? 0:1)) * ic;
    }      
    /* Result should always have same sign as 2nd argument. (PIL2) */
    lua_assert( (v<0) ? (ic<0) : (v>0) ? (ic>0) : 1 );
    *r= v;
    return 1;
  }
  return 0;  /* let float side return NaN */
}

lu_bool try_powint( lua_Integer *r, lua_Integer ib, lua_Integer ic ) {
  /* Fallback to floats would not hurt (no accuracy lost) but we can do
   * some common cases (2^N where N=[0..30]) for speed.
   */
  if (ib==2 && ic>=0 && ic <= 30) {
    *r= 1<<ic;   /* 1,2,4,...2^30 */
    return 1;
  }
  return 0;
}

lu_bool try_unmint( lua_Integer *r, lua_Integer ib ) {
  /* Negating -2^31 leaves the range. */
  if ( ib != LUA_INTEGER_MIN )  
    { *r= -ib; return 1; }
  return 0;
}


#ifdef LNUM_COMPLEX
/* Complex modulus:
 * 
 * C99 does not provide modulus for complex numbers. We should at least 
 * give an error here.
 *
 * TBD: Not sure if there's a standard way to do this?  Anyways, in the ways
 *      Lua is using '%' for range rounding, this behaviour should be practical?
 */
lua_Complex luai_vectmod( lua_Complex a, lua_Complex b )
{
    return luai_nummod( creal(a), creal(b) ) + luai_nummod( cimag(a), cimag(b) ) * I;
}


/* Complex power
 * [(a+bi)^(c+di)] = (r^c) * exp(-d*t) * cos(c*t + d*ln(r)) +
 *                 = (r^c) * exp(-d*t) * sin(c*t + d*ln(r)) *i
 * r = sqrt(a^2+b^2), t = arctan( b/a )
 * 
 * References/credits: <http://home.att.net/~srschmitt/complexnumbers.html>
 * Could also be calculated using: x^y = exp(ln(x)*y)
 */
lua_Complex luai_vectpow( lua_Complex a, lua_Complex b )
{
/* Better to use <complex.h> to avoid calculation inaccuracies: (1i)^2 should be -1, sharp. :)
*
* HA!  Even cpow() does it with exact same inaccuracies:
*       > print( (1i)^2 )
*       -1+1.2246467991474e-16i
*/
#if false
    lua_Number ar= creal(a), ai= cimag(a);
    lua_Number br= creal(b), bi= cimag(b);

    lua_assert( r );
    
    if (ai==0 && bi==0) {     /* a^c (real) */
      return luai_numpow( creal(a), creal(b) ) /* no I */; 
    } 

    if ( ai!=0 && bi==0 && floor(br)==br && br!=0) { /* (a+bi)^N, N = { +-1,+-2, ... } */
      lua_Number k= luai_numpow( sqrt(ar*ar + ai*ai), br );
      lua_Number cos_z, sin_z;

      /* Situation depends upon c (N) in the following manner:
       * 
       * N%4==0                                => cos(c*t)=1, sin(c*t)=0
       * (N*sign(b))%4==1 or (N*sign(b))%4==-3 => cos(c*t)=0, sin(c*t)=1
       * N%4==2 or N%4==-2                     => cos(c*t)=-1, sin(c*t)=0
       * (N*sign(b))%4==-1 or (N*sign(b))%4==3 => cos(c*t)=0, sin(c*t)=-1
       */
      switch( (abs(br)%4) * (br<0 ? -1:1) * (ai<0 ? -1:1) ) {
        case 0:             cos_z=1, sin_z=0; break;
        case 2: case -2:    cos_z=-1, sin_z=0; break;
        case 1: case -3:    cos_z=0, sin_z=1; break;
        case 3: case -1:    cos_z=0, sin_z=-1; break;
        default:            lua_assert(0);
      }
      return k*cos_z + k*sin_z*I;
    }
#endif

    lua_assert( r );
    return cpow( a, b );
}
#endif


