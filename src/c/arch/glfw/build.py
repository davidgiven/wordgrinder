from build.c import cxxlibrary
from build.pkg import package
from tools.build import multibin
from config import HAS_OSX, HAS_HAIKU, IS_WINDOWS

package(name="libglfw3", package="glfw3", fallback="src/c/glfw-fallback")
package(name="opengl", package="opengl")

multibin(
    name="font_table",
    symbol="font_table",
    srcs=[
        "extras/fonts/FantasqueSansMono-Regular.ttf",
        "extras/fonts/FantasqueSansMono-Italic.ttf",
        "extras/fonts/FantasqueSansMono-Bold.ttf",
        "extras/fonts/FantasqueSansMono-BoldItalic.ttf",
    ],
)

cxxlibrary(
    name="glfw",
    srcs=[
        "./font.cc",
        "./main.cc",
        "./utils.cc",
        "tools+icon_cc",
    ],
    hdrs={"font_table.h": ".+font_table"},
    cflags=(["-I./src/c"] + ["-DGL_SILENCE_DEPRECATION"] if HAS_OSX else []),
    deps=[
        ".+libglfw3",
        "src/c+globals",
        "src/c/luau-em",
        "third_party/libstb",
        "third_party/luau",
    ]
    + ([] if IS_WINDOWS or HAS_OSX or HAS_HAIKU else [".+opengl"]),
)
