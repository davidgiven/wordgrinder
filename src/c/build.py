from build.ab2 import DefaultVars
from build.c import cxxprogram, clibrary
from config import FILEFORMAT

clibrary(
    name="globals",
    srcs=[],
    hdrs=["./globals.h"],
    vars=DefaultVars
    + {
        "+cxxflags": [
            f"-DFILEFORMAT={FILEFORMAT}",
            "-I.",
        ]
    },
    exportvars={
        "+cxxflags": [f"-DFILEFORMAT={FILEFORMAT}", "-I."],
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
        "+globals",
        "src/c/arch/ncurses",
        "third_party/clip+clip_none",
        "third_party/luau",
        "third_party/minizip",
    ],
)
