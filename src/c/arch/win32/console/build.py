from build.c import clibrary

clibrary(
    name="console",
    srcs=["./dpy.cc", "./realmain.cc"],
    cflags=["-Isrc/c"],
    deps=[
        "src/c+globals",
        "src/c/luau-em",
        "third_party/libstb",
        "third_party/luau",
    ],
)
