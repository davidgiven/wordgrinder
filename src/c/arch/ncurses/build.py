from build.ab2 import DefaultVars
from build.c import clibrary

clibrary(
    name="ncurses",
    srcs=["./dpy.cc"],
    vars=DefaultVars + {"+cflags": ["-Isrc/c"]},
    deps=["src/c+globals", "third_party/libstb"],
    exportvars={"+ldflags": ["-lncursesw"]},
)
