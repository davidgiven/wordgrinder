#if defined WIN32

#include <windows.h>
#include <direct.h>

extern wchar_t* utf8_to_wide(lua_State* L, const char* utf8);
extern void lua_pushwstring(lua_State* L, const wchar_t* wide);

#endif

