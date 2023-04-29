from build.ab2 import DefaultVars
from build.c import clibrary
from build.pkg import package

clibrary(
    name="console",
    srcs=[
        "./dpy.cc",
        "./realmain.cc"
    ],
    vars=DefaultVars + {"+cflags": ["-Isrc/c"]},
    deps=[
        "src/c+globals",
        "src/c/luau-em",
        "third_party/libstb",
        "third_party/luau",
    ],
)

