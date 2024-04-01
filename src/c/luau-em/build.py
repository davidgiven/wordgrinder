from build.c import cxxlibrary

cxxlibrary(
    name="luau-em",
    srcs=["./lauxlib.cc"],
    hdrs={"lauxlib.h": "./lauxlib.h"},
    deps=["third_party/luau"],
)
