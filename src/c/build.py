from build.ab import simplerule
from build.c import cxxprogram, cxxlibrary
from build.pkg import package
from config import (
    FILEFORMAT,
    HAS_OSX,
    HAS_NCURSES,
    HAS_XWORDGRINDER,
    DEFAULT_DICTIONARY_PATH,
)

package(name="libcmark", package="libcmark", fallback="third_party/cmark")
package(name="fmt", package="fmt", fallback="third_party/fmt")

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
    caller_cflags=[f"-DFILEFORMAT={FILEFORMAT}"],
    deps=[
        ".+fmt",
        ".+libcmark",
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
        cflags=cflags
        + [
            f"-DDEFAULT_DICTIONARY_PATH={DEFAULT_DICTIONARY_PATH}",
        ],
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


if HAS_NCURSES:
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

if HAS_XWORDGRINDER:
    make_wordgrinder(
        "wordgrinder-glfw-x11",
        deps=[
            "src/c/arch/glfw",
            "third_party/libstb",
            "third_party/clip+clip_x11",
        ],
        cflags=["-DFRONTEND=glfw"],
    )

if HAS_OSX:
    make_wordgrinder(
        "wordgrinder-glfw-osx",
        deps=[
            "src/c/arch/glfw",
            "third_party/libstb",
            "third_party/clip+clip_osx",
        ],
        cflags=["-DFRONTEND=glfw"],
        ldflags=["-framework Cocoa", "-framework OpenGL"],
    )

    simplerule(
        name="wordgrinder_pkg",
        ins=[".+wordgrinder_app"],
        outs=["=wordgrinder-component.pkg"],
        commands=[
            "pkgbuild --quiet --install-location /Applications --component $[ins[0]] $[outs[0]]"
        ],
        label="PKGBUILD",
    )

    simplerule(
        name="wordgrinder_app",
        ins=[
            ".+wordgrinder-glfw-osx",
            "extras+wordgrinder_icns",
            "extras/WordGrinder.app.template/",
        ],
        outs=["=wordgrinder.app"],
        commands=[
            "rm -rf $[outs[0]]",
            "cp -a $[ins[2]] $[outs[0]]",
            "touch $[outs[0]]",
            "cp $[ins[0]] $[outs[0]]/Contents/MacOS/wordgrinder",
            "mkdir -p $[outs[0]]/Contents/Resources",
            "cp $[ins[1]] $[outs[0]]/Contents/Resources/wordgrinder.icns",
            "dylibbundler -of -x $[outs[0]]/Contents/MacOS/wordgrinder -b -d $[outs[0]]/Contents/libs -cd > /dev/null",
            "cp $$(brew --prefix fmt)/LICENSE* $[outs[0]]/Contents/libs/fmt.rst",
            "cp $$(brew --prefix glfw)/LICENSE* $[outs[0]]/Contents/libs/glfw.md",
        ],
        label="MKAPP",
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
