from build.c import cxxlibrary
from build.pkg import package
from config import HAS_NCURSES

if HAS_NCURSES:
    package(name="libncursesw", package="ncursesw")

    cxxlibrary(
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
