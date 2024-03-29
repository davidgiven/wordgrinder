from build.ab2 import DefaultVars
from build.c import clibrary
from build.pkg import package
from tools.build import multibin
import platform

package(name="libglfw3", package="glfw3")
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

clibrary(
    name="glfw",
    srcs=[
        "./font.cc",
        "./main.cc",
        "./utils.cc",
        "+font_table",
        "tools+icon_cc",
    ],
    vars=DefaultVars
    + {
        "+cxxflags": ["-I./src/c"] + ["-DGL_SILENCE_DEPRECATION"]
        if platform.system() == "Darwin"
        else []
    },
    deps=[
        "+libglfw3",
        "+opengl",
        "src/c+globals",
        "src/c/luau-em",
        "third_party/libstb",
        "third_party/luau",
    ],
)
