/*
** LuaFileSystem
** Copyright Kepler Project 2004-2006 (http://www.keplerproject.org/luafilesystem)
**
** $Id$
*/

/* Define 'chdir' for systems that do not implement it */
#ifdef NO_CHDIR
#define chdir(p)	(-1)
#define chdir_error	"Function 'chdir' not provided by system"
#else
#define chdir_error	strerror(errno)
#endif

extern int luaopen_lfs (lua_State *L);
