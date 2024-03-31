from build.c import cxxprogram, cxxlibrary
from build.pkg import package
from config import FILEFORMAT

package(name="libcmark", package="libcmark")
package(name="fmt", package="fmt")

cxxlibrary(
    name="globals",
    srcs=[
        "./utils.cc",
        "./cmark.cc",
        "./filesystem.cc",
        "./main.cc",
        "./screen.cc",
        "./word.cc",
        "./zip.cc",
    ],
    hdrs={"globals.h": "./globals.h", "script_table.h": "src/lua+luacode"},
    cflags=[
        f"-DFILEFORMAT={FILEFORMAT}",
        "-DCMARK_STATIC_DEFINE",
        "-I.",
    ],
    caller_cflags=f"-DFILEFORMAT={FILEFORMAT}",
    deps=[
        ".+fmt",
        "third_party/luau",
        "third_party/wcwidth",
        "src/c/luau-em",
        "third_party/minizip",
    ],
)


def make_wordgrinder(name, deps=[], cflags=[], ldflags=[]):
    cxxprogram(
        name=name,
        srcs=[
            "./lua.cc",
            "./clipboard.cc",
        ],
        cflags=cflags,
        ldflags=ldflags,
        deps=[
            ".+libcmark",
            ".+globals",
            "third_party/clip+clip_common",
            "third_party/luau",
            "third_party/minizip",
            "third_party/wcwidth",
            "src/c/luau-em",
        ]
        + deps,
    )


make_wordgrinder(
    "wordgrinder-ncurses",
    deps=[
        "src/c/arch/ncurses",
        "third_party/clip+clip_none",
        "third_party/wcwidth",
    ],
    cflags=["-DFRONTEND=ncurses"],
)

make_wordgrinder(
    "wordgrinder-wincon",
    deps=[
        "src/c/arch/win32",
        "src/c/arch/win32/console",
        "third_party/clip+clip_none",
    ],
    cflags=["-DFRONTEND=wincon"],
    ldflags=[
        "-mconsole",
        "-lole32",
        "-lshlwapi",
        "-lwindowscodecs",
        "-lrpcrt4",
    ],
)

make_wordgrinder(
    "wordgrinder-glfw-x11",
    deps=["src/c/arch/glfw", "third_party/libstb", "third_party/clip+clip_x11"],
    cflags=["-DFRONTEND=glfw"],
)

make_wordgrinder(
    "wordgrinder-glfw-osx",
    deps=["src/c/arch/glfw", "third_party/libstb", "third_party/clip+clip_osx"],
    cflags=["-DFRONTEND=glfw"],
    ldflags=["-framework", "Cocoa", "-framework", "OpenGL"],
)

make_wordgrinder(
    "wordgrinder-glfw-windows",
    deps=[
        "src/c/arch/win32",
        "src/c/arch/glfw",
        "third_party/libstb",
        "third_party/clip+clip_win",
    ],
    cflags=["-DFRONTEND=glfw"],
    ldflags=[
        "-static",
        "-static-libgcc",
        "-static-libstdc++",
        "-lssp",
        "-mwindows",
        "-lole32",
        "-lshlwapi",
        "-lwindowscodecs",
        "-lrpcrt4",
        "-lopengl32",
        "-lgdi32",
    ],
)

make_wordgrinder(
    "wordgrinder-glfw-haiku",
    deps=[
        "src/c/arch/glfw",
        "third_party/libstb",
        "third_party/clip+clip_none",
    ],
    cflags=["-DFRONTEND=glfw"],
    ldflags=["-lGL"],
)
