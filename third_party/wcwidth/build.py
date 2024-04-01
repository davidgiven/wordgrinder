from build.c import cxxlibrary

cxxlibrary(
    name="wcwidth",
    srcs=["./wcwidth.cc"],
)
