from build.ab2 import DefaultVars
from build.c import cxxprogram, clibrary
from build.pkg import has_package
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


def make_wordgrinder(name, arch, frontend, clip):
    cxxprogram(
        name=name,
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
            arch,
            "third_party/clip+" + clip,
            "third_party/luau",
            "third_party/minizip",
            "src/c/luau-em",
        ],
        vars=DefaultVars + {"+cxxflags": ["-DFRONTEND=" + frontend]},
    )


make_wordgrinder(
    "wordgrinder-ncurses", "src/c/arch/ncurses", "ncurses", "clip_none"
)
make_wordgrinder("wordgrinder-glfw", "src/c/arch/glfw", "glfw", "clip_x11")
