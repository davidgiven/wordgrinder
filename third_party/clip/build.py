from build.c import cxxlibrary
from build.pkg import package
from config import HAS_XWORDGRINDER

cxxlibrary(
    name="clip_common",
    srcs=["./clip.cpp", "./image.cpp"],
    hdrs={
        "clip.h": "./clip.h",
        "clip_lock_impl.h": "./clip_lock_impl.h",
        "clip_common.h": "./clip_common.h",
    },
)

cxxlibrary(
    name="clip_none",
    srcs=["./clip_none.cpp"],
    hdrs={"clip.h": "./clip.h"},
    deps=[".+clip_common"],
)

if HAS_XWORDGRINDER:
    package(name="xcb", package="xcb")
    cxxlibrary(
        name="clip_x11",
        srcs=["./clip_x11.cpp"],
        hdrs={"clip.h": "./clip.h"},
        deps=[".+clip_common", ".+xcb"],
    )

cxxlibrary(
    name="clip_osx",
    srcs=["./clip_osx.mm"],
    hdrs={"clip.h": "./clip.h"},
    deps=[".+clip_common"],
)

cxxlibrary(
    name="clip_win",
    srcs=["./clip_win.cpp"],
    hdrs={"clip.h": "./clip.h"},
    deps=[".+clip_common"],
)
