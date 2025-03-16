from build.c import cxxlibrary, cxxprogram
from glob import glob
from pathlib import Path
import sys


def _compute_header_name(f):
    parts = list(f.relative_to("third_party/luau").parts)
    return "/".join(parts[2:])


LUAU_SRCS = [
    f.as_posix()
    for f in (
        list(Path("third_party/luau").glob("*/src/*.cpp"))
        + list(Path("third_party/luau").glob("*/src/*.h"))
    )
    if ("/CLI" not in f.as_posix())
]
LUAU_HDRS = {
    _compute_header_name(f): f.as_posix()
    for f in Path("third_party/luau").glob("**/*.h")
    if ("/VM/" not in f.as_posix())
    and ("/CLI/" not in f.as_posix())
    and ("/include/" in f.as_posix())
}

cxxlibrary(
    name="luau",
    srcs=LUAU_SRCS,
    hdrs=LUAU_HDRS
    | {
        "lua.h": "./VM/include/lua.h",
        "luaconf.h": "./VM/include/luaconf.h",
        "lualib.h": "./VM/include/lualib.h",
        "lobject.h": "./VM/src/lobject.h",
        "ldebug.h": "./VM/src/ldebug.h",
        "lcommon.h": "./VM/src/lcommon.h",
        "lstate.h": "./VM/src/lstate.h",
        "ltm.h": "./VM/src/ltm.h",
        "ldo.h": "./VM/src/ldo.h",
        "lapi.h": "./VM/src/lapi.h",
        "lgc.h": "./VM/src/lgc.h",
        "lnumutils.h": "./VM/src/lnumutils.h",
        "lbuiltins.h": "./VM/src/lbuiltins.h",
        "ltable.h": "./VM/src/ltable.h",
        "lvm.h": "./VM/src/lvm.h",
        "lfunc.h": "./VM/src/lfunc.h",
        "lbytecode.h": "./VM/src/lbytecode.h",
        "lmem.h": "./VM/src/lmem.h",
        "lstring.h": "./VM/src/lstring.h",
        "ludata.h": "./VM/src/ludata.h",
    },
)

cxxprogram(
    name="analyse",
    srcs=[
        "./CLI/Analyze.cpp",
        "./CLI/FileUtils.cpp",
        "./CLI/Flags.cpp",
    ],
    deps=[".+luau"],
)
