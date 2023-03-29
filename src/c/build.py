from build.ab2 import DefaultVars
from build.c import cxxprogram, clibrary
from build.pkg import has_package, package
from config import FILEFORMAT

clibrary(
    name="globals",
    srcs=[
        "./utils.cc",
        "./cmark.cc",
        "./filesystem.cc",
        "./main.cc",
        "./screen.cc",
        "./word.cc",
        "./zip.cc",
        "src/lua+luacode",
    ],
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
    deps=[
        "third_party/luau",
        "src/c/luau-em",
        "third_party/minizip",
    ],
)

package(name="libcmark", package="libcmark")


def make_wordgrinder(name, arch, frontend, clip):
    cxxprogram(
        name=name,
        srcs=[
            "./lua.cc",
            "./clipboard.cc",
        ],
        deps=[
            "+libcmark",
            "+globals",
            arch,
            "third_party/clip+" + clip,
            "third_party/luau",
            "src/c/luau-em",
        ],
        vars=DefaultVars + {"+cxxflags": ["-DFRONTEND=" + frontend]},
    )


make_wordgrinder(
    "wordgrinder-ncurses", "src/c/arch/ncurses", "ncurses", "clip_none"
)
make_wordgrinder("wordgrinder-glfw", "src/c/arch/glfw", "glfw", "clip_x11")
