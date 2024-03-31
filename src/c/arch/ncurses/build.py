from build.c import clibrary
from build.pkg import package

package(name="libncursesw", package="ncursesw")

clibrary(
    name="ncurses",
    srcs=["./dpy.cc"],
    deps=[
        ".+libncursesw",
        "src/c+globals",
        "src/c/luau-em",
        "third_party/libstb",
        "third_party/luau",
    ],
)
