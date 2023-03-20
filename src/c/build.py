from build.ab2 import DefaultVars
from build.c import cxxprogram, clibrary
from config import FILEFORMAT

clibrary(
    name="globals",
    srcs=[],
    hdrs=["./globals.h"],
    vars=DefaultVars
    + {
        "+cflags": [
            f"-DFILEFORMAT={FILEFORMAT}",
            "-I.",
        ]
    },
    exportvars={
        "+cflags": [f"-DFILEFORMAT={FILEFORMAT}", "-I."],
    },
)

cxxprogram(
    name="wordgrinder",
    srcs=[
        "./clipboard.cc",
        "./filesystem.cc",
        "./lua.cc",
        "./main.cc",
        "./screen.cc",
        "./utils.cc",
        "./word.cc",
        "./zip.cc",
        "src/lua+luacode",
    ],
    deps=[
        "third_party/luau",
        "src/c/arch/ncurses",
        "third_party/clip+clip_none",
        "src/c/emu/minizip",
        "+globals",
    ],
)
