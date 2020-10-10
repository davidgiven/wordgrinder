#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
#include "winshim.h"

#if defined WIN32

wchar_t* utf8_to_wide(lua_State* L, const char* utf8)
{
   	int size16 = MultiByteToWideChar(CP_UTF8, 0, utf8, -1, 0, 0);
	wchar_t* wide = lua_newuserdata(L, (size16+1) * sizeof(wchar_t));
    MultiByteToWideChar(CP_UTF8, 0, utf8, -1, wide, size16);
	return wide;
}

void lua_pushwstring(lua_State* L, const wchar_t* wide)
{
	int size8 = WideCharToMultiByte(CP_UTF8, 0, wide, -1, NULL, 0, 0, 0);
	char utf8[size8];
	WideCharToMultiByte(CP_UTF8, 0, wide, -1, utf8, size8, 0, 0);
	lua_pushstring(L, utf8);
}

#endif
