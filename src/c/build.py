from build.ab2 import DefaultVars
from build.c import cxxprogram, clibrary
from build.pkg import has_package, package
from config import FILEFORMAT

package(name="libcmark", package="libcmark")
package(name="fmt", package="fmt")

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
        "+fmt",
        "third_party/luau",
        "src/c/luau-em",
        "third_party/minizip",
    ],
)


def make_wordgrinder(name, arch, clip, vars={}):
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
        vars=DefaultVars + vars,
    )


make_wordgrinder(
    "wordgrinder-ncurses",
    "src/c/arch/ncurses",
    "clip_none",
    vars={"+cxxflags": ["-DFRONTEND=ncurses"]},
)

make_wordgrinder(
    "wordgrinder-glfw-x11",
    "src/c/arch/glfw",
    "clip_x11",
    vars={"+cxxflags": ["-DFRONTEND=glfw"]},
)

make_wordgrinder(
    "wordgrinder-glfw-osx",
    "src/c/arch/glfw",
    "clip_osx",
    vars={
        "+cxxflags": ["-DFRONTEND=glfw"],
        "+ldflags": ["-framework", "Cocoa", "-framework", "OpenGL"],
    },
)
