/*
** $Id$
** Type definitions for Lua objects
** See Copyright Notice in lua.h
*/


#ifndef lobject_h
#define lobject_h


#include <stdarg.h>


#include "llimits.h"
#include "lua.h"


/* tags for values visible from Lua */
#if defined(LUA_TINT) && (LUA_TINT > LUA_TTHREAD)
# define LAST_TAG   LUA_TINT
#else
# define LAST_TAG	LUA_TTHREAD
#endif

#define NUM_TAGS	(LAST_TAG+1)


/*
** Extra tags for non-values
*/
#define LUA_TPROTO	(LAST_TAG+1)
#define LUA_TUPVAL	(LAST_TAG+2)
#define LUA_TDEADKEY	(LAST_TAG+3)


/*
** Union of all collectable objects
*/
typedef union GCObject GCObject;


/*
** Common Header for all collectable objects (in macro form, to be
** included in other objects)
*/
#define CommonHeader	GCObject *next; lu_byte tt; lu_byte marked


/*
** Common header in struct form
*/
typedef struct GCheader {
  CommonHeader;
} GCheader;




/*
** Union of all Lua values
*/
/* Number mode invariants:
   LUA_TINT: any integer fitting in 'lua_Integer' is _always_ carried in .i,
             never in .n. This applies to complex numbers as well (for scalars).
*/            
typedef union {
  GCObject *gc;
  void *p;
#ifdef LNUM_COMPLEX
  /* Naming this the same as 'lua_Number' field simplifies code; complex can
   * be assigned a number as such, or 'x + y*I'. */
  lua_Complex n;
#else
  lua_Number n;
#endif
#ifdef LUA_TINT
  lua_Integer i;
#endif
  int b;
} Value;


/*
** Tagged Values
*/

#define TValuefields	Value value; int tt

typedef struct lua_TValue {
  TValuefields;
} TValue;


/* Macros to test type */
#define ttisnil(o)	(ttype(o) == LUA_TNIL)
#ifdef LUA_TINT
# define ttisinteger(o) (ttype(o) == LUA_TINT)
# define ttisnumber(o) ((ttype(o) == LUA_TINT) || (ttype(o) == LUA_TNUMBER))
  /* 'ttisnumber_raw()' for non-int32 numbers (gives FALSE on int32's) */
# define ttisnumber_raw(o)	(ttype(o) == LUA_TNUMBER)
#else
# define ttisnumber(o)	(ttype(o) == LUA_TNUMBER)
#endif
#ifdef LNUM_COMPLEX
# define ttiscomplex(o) ((ttype(o) == LUA_TNUMBER) && (nvalue_img_fast(o)!=0))
#endif
#define ttisstring(o)	(ttype(o) == LUA_TSTRING)
#define ttistable(o)	(ttype(o) == LUA_TTABLE)
#define ttisfunction(o)	(ttype(o) == LUA_TFUNCTION)
#define ttisboolean(o)	(ttype(o) == LUA_TBOOLEAN)
#define ttisuserdata(o)	(ttype(o) == LUA_TUSERDATA)
#define ttisthread(o)	(ttype(o) == LUA_TTHREAD)
#define ttislightuserdata(o)	(ttype(o) == LUA_TLIGHTUSERDATA)

/* Macros to access values */
#define ttype(o)	((o)->tt)
#define gcvalue(o)	check_exp(iscollectable(o), (o)->value.gc)
#define pvalue(o)	check_exp(ttislightuserdata(o), (o)->value.p)

#ifdef LUA_TINT
# define ttype2(o)  ( ttype(o) == LUA_TINT ? LUA_TNUMBER : ttype(o) )
#else
# define ttype2 ttype
#endif

/* 
 * '_fast' variants are for cases where the value is known to be non-integer.
 *
 * Note: We could require LNUM_INTxx always with LNUM_COMPLEX, it would simplify
 *       #ifdef's below a bit (but orthogonality is a virtue :) ).
 *       N.B. Two hard to crack places, in 'lvm.c' and 'liolib.c'.. :/
 */
#ifdef LNUM_COMPLEX
#  define nvalue_complex_fast(o) check_exp( ttype(o)==LUA_TNUMBER, (o)->value.n )   
#  define nvalue_fast(o)     creal( nvalue_complex_fast(o) )
#  define nvalue_img_fast(o) cimag( nvalue_complex_fast(o) )
# ifdef LUA_TINT
#  define nvalue_complex(o) check_exp( ttisnumber(o), (ttype(o)==LUA_TINT) ? (o)->value.i : (o)->value.n )
#  define nvalue_img(o) check_exp( ttisnumber(o), (ttype(o)==LUA_TINT) ? 0 : cimag( (o)->value.n ) ) 
#  define nvalue(o) check_exp( ttisnumber(o), (ttype(o)==LUA_TINT) ? cast_num((o)->value.i) : creal((o)->value.n) ) 
# else
#  define nvalue_complex(o) check_exp( ttisnumber(o), (o)->value.n )
#  define nvalue_img(o) check_exp( ttisnumber(o), cimag( (o)->value.n ) ) 
#  define nvalue(o) check_exp( ttisnumber(o), creal((o)->value.n) ) 
# endif
#elif defined(LUA_TINT)
# define nvalue(o)	check_exp( ttisnumber(o), (ttype(o)==LUA_TINT) ? cast_num((o)->value.i) : (o)->value.n )
# define nvalue_fast(o) check_exp( ttype(o)==LUA_TNUMBER, (o)->value.n )   
#else
# define nvalue(o)	check_exp(ttisnumber(o), (o)->value.n)
#endif

#ifdef LUA_TINT
# define ivalue(o)	check_exp( ttype(o)==LUA_TINT, (o)->value.i )
#else
# define ivalue(o) cast(int,nvalue(o))
#endif

#define rawtsvalue(o)	check_exp(ttisstring(o), &(o)->value.gc->ts)
#define tsvalue(o)	(&rawtsvalue(o)->tsv)
#define rawuvalue(o)	check_exp(ttisuserdata(o), &(o)->value.gc->u)
#define uvalue(o)	(&rawuvalue(o)->uv)
#define clvalue(o)	check_exp(ttisfunction(o), &(o)->value.gc->cl)
#define hvalue(o)	check_exp(ttistable(o), &(o)->value.gc->h)
#define bvalue(o)	check_exp(ttisboolean(o), (o)->value.b)
#define thvalue(o)	check_exp(ttisthread(o), &(o)->value.gc->th)

#define l_isfalse(o)	(ttisnil(o) || (ttisboolean(o) && bvalue(o) == 0))

/*
** for internal debug only
*/
#define checkconsistency(obj) \
  lua_assert(!iscollectable(obj) || (ttype(obj) == (obj)->value.gc->gch.tt))

#define checkliveness(g,obj) \
  lua_assert(!iscollectable(obj) || \
  ((ttype(obj) == (obj)->value.gc->gch.tt) && !isdead(g, (obj)->value.gc)))


/* Macros to set values */
#define setnilvalue(obj) ((obj)->tt=LUA_TNIL)

#ifdef LUA_TINT
    /* Must not have side effects, 'x' may be expression.
     */
# define setivalue(obj,x) \
    { TValue *i_o=(obj); i_o->value.i=(x); i_o->tt=LUA_TINT; }

  /* Note: The casting to 'lua_Integer' and then checking for equality
   *       simultaneously checks _both_ no fraction _and_ valid range.
   */
# define setnvalue(obj,x) \
    { TValue *i_o=(obj); lua_Number xx=(x); \
         lua_number2integer(i_o->value.i,xx); \
         if (xx==i_o->value.i) i_o->tt=LUA_TINT; \
         else { i_o->value.n= xx; i_o->tt=LUA_TNUMBER; } \
    }

  /* This to be used when we KNOW that a value is not an integer.
  */
# define setnvalue_fast(obj,x) \
    { TValue *i_o=(obj); i_o->value.n= (x); i_o->tt=LUA_TNUMBER; }

#else
/* not LUA_TINT (pure FP) */
# define setnvalue(obj,x) \
    { TValue *i_o=(obj); i_o->value.n=(x); i_o->tt=LUA_TNUMBER; }
  
# define setivalue(obj,x) \
    setnvalue( (obj), cast(lua_Number, (x)) )
#endif

/* Note: Complex always has "inline", both are C99.
*/
#ifdef LNUM_COMPLEX
  static inline void setnvalue_complex( TValue *obj, lua_Complex x ) {
    if (cimag(x) == 0.0) { setnvalue(obj, creal(x)); }
    else { obj->value.n= x; obj->tt= LUA_TNUMBER; }
  }
# ifdef LUA_TINT
#  define setnvalue_complex_fast setnvalue_fast
# else
#  define setnvalue_complex_fast setnvalue
# endif
#endif


#define setpvalue(obj,x) \
  { TValue *i_o=(obj); i_o->value.p=(x); i_o->tt=LUA_TLIGHTUSERDATA; }

#define setbvalue(obj,x) \
  { TValue *i_o=(obj); i_o->value.b=(x); i_o->tt=LUA_TBOOLEAN; }

#define setsvalue(L,obj,x) \
  { TValue *i_o=(obj); \
    i_o->value.gc=cast(GCObject *, (x)); i_o->tt=LUA_TSTRING; \
    checkliveness(G(L),i_o); }

#define setuvalue(L,obj,x) \
  { TValue *i_o=(obj); \
    i_o->value.gc=cast(GCObject *, (x)); i_o->tt=LUA_TUSERDATA; \
    checkliveness(G(L),i_o); }

#define setthvalue(L,obj,x) \
  { TValue *i_o=(obj); \
    i_o->value.gc=cast(GCObject *, (x)); i_o->tt=LUA_TTHREAD; \
    checkliveness(G(L),i_o); }

#define setclvalue(L,obj,x) \
  { TValue *i_o=(obj); \
    i_o->value.gc=cast(GCObject *, (x)); i_o->tt=LUA_TFUNCTION; \
    checkliveness(G(L),i_o); }

#define sethvalue(L,obj,x) \
  { TValue *i_o=(obj); \
    i_o->value.gc=cast(GCObject *, (x)); i_o->tt=LUA_TTABLE; \
    checkliveness(G(L),i_o); }

#define setptvalue(L,obj,x) \
  { TValue *i_o=(obj); \
    i_o->value.gc=cast(GCObject *, (x)); i_o->tt=LUA_TPROTO; \
    checkliveness(G(L),i_o); }

#define setobj(L,obj1,obj2) \
  { const TValue *o2=(obj2); TValue *o1=(obj1); \
    o1->value = o2->value; o1->tt=o2->tt; \
    checkliveness(G(L),o1); }


/*
** different types of sets, according to destination
*/

/* from stack to (same) stack */
#define setobjs2s	setobj
/* to stack (not from same stack) */
#define setobj2s	setobj
#define setsvalue2s	setsvalue
#define sethvalue2s	sethvalue
#define setptvalue2s	setptvalue
/* from table to same table */
#define setobjt2t	setobj
/* to table */
#define setobj2t	setobj
/* to new object */
#define setobj2n	setobj
#define setsvalue2n	setsvalue

#define setttype(obj, tt) (ttype(obj) = (tt))

/* Note: When LUA_TINT is fixed (preferably to LUA_TNUMBER+1), this can be reduced.
 */
#if defined(LUA_TINT) && (LUA_TINT >= LUA_TSTRING)
# define iscollectable(o)	((ttype(o) >= LUA_TSTRING) && (ttype(o) != LUA_TINT))
#else
# define iscollectable(o)	(ttype(o) >= LUA_TSTRING)
#endif



typedef TValue *StkId;  /* index to stack elements */


/*
** String headers for string table
*/
typedef union TString {
  L_Umaxalign dummy;  /* ensures maximum alignment for strings */
  struct {
    CommonHeader;
    lu_byte reserved;
    unsigned int hash;
    size_t len;
  } tsv;
} TString;


#define getstr(ts)	cast(const char *, (ts) + 1)
#define svalue(o)       getstr(tsvalue(o))



typedef union Udata {
  L_Umaxalign dummy;  /* ensures maximum alignment for `local' udata */
  struct {
    CommonHeader;
    struct Table *metatable;
    struct Table *env;
    size_t len;
  } uv;
} Udata;




/*
** Function Prototypes
*/
typedef struct Proto {
  CommonHeader;
  TValue *k;  /* constants used by the function */
  Instruction *code;
  struct Proto **p;  /* functions defined inside the function */
  int *lineinfo;  /* map from opcodes to source lines */
  struct LocVar *locvars;  /* information about local variables */
  TString **upvalues;  /* upvalue names */
  TString  *source;
  int sizeupvalues;
  int sizek;  /* size of `k' */
  int sizecode;
  int sizelineinfo;
  int sizep;  /* size of `p' */
  int sizelocvars;
  int linedefined;
  int lastlinedefined;
  GCObject *gclist;
  lu_byte nups;  /* number of upvalues */
  lu_byte numparams;
  lu_byte is_vararg;
  lu_byte maxstacksize;
} Proto;


/* masks for new-style vararg */
#define VARARG_HASARG		1
#define VARARG_ISVARARG		2
#define VARARG_NEEDSARG		4


typedef struct LocVar {
  TString *varname;
  int startpc;  /* first point where variable is active */
  int endpc;    /* first point where variable is dead */
} LocVar;



/*
** Upvalues
*/

typedef struct UpVal {
  CommonHeader;
  TValue *v;  /* points to stack or to its own value */
  union {
    TValue value;  /* the value (when closed) */
    struct {  /* double linked list (when open) */
      struct UpVal *prev;
      struct UpVal *next;
    } l;
  } u;
} UpVal;


/*
** Closures
*/

#define ClosureHeader \
	CommonHeader; lu_byte isC; lu_byte nupvalues; GCObject *gclist; \
	struct Table *env

typedef struct CClosure {
  ClosureHeader;
  lua_CFunction f;
  TValue upvalue[1];
} CClosure;


typedef struct LClosure {
  ClosureHeader;
  struct Proto *p;
  UpVal *upvals[1];
} LClosure;


typedef union Closure {
  CClosure c;
  LClosure l;
} Closure;


#define iscfunction(o)	(ttype(o) == LUA_TFUNCTION && clvalue(o)->c.isC)
#define isLfunction(o)	(ttype(o) == LUA_TFUNCTION && !clvalue(o)->c.isC)


/*
** Tables
*/

typedef union TKey {
  struct {
    TValuefields;
    struct Node *next;  /* for chaining */
  } nk;
  TValue tvk;
} TKey;


typedef struct Node {
  TValue i_val;
  TKey i_key;
} Node;


typedef struct Table {
  CommonHeader;
  lu_byte flags;  /* 1<<p means tagmethod(p) is not present */ 
  lu_byte lsizenode;  /* log2 of size of `node' array */
  struct Table *metatable;
  TValue *array;  /* array part */
  Node *node;
  Node *lastfree;  /* any free position is before this position */
  GCObject *gclist;
  int sizearray;  /* size of `array' array */
} Table;



/*
** `module' operation for hashing (size is always a power of 2)
*/
#define lmod(s,size) \
	(check_exp((size&(size-1))==0, (cast(int, (s) & ((size)-1)))))


#define twoto(x)	(1<<(x))
#define sizenode(t)	(twoto((t)->lsizenode))


#define luaO_nilobject		(&luaO_nilobject_)

LUAI_DATA const TValue luaO_nilobject_;

#define ceillog2(x)	(luaO_log2((x)-1) + 1)

LUAI_FUNC int luaO_log2 (unsigned int x);
LUAI_FUNC int luaO_int2fb (unsigned int x);
LUAI_FUNC int luaO_fb2int (int x);
LUAI_FUNC int luaO_rawequalObj (const TValue *t1, const TValue *t2);
LUAI_FUNC const char *luaO_pushvfstring (lua_State *L, const char *fmt,
                                                       va_list argp);
LUAI_FUNC const char *luaO_pushfstring (lua_State *L, const char *fmt, ...);
LUAI_FUNC void luaO_chunkid (char *out, const char *source, size_t len);

#endif

