from build.c import clibrary, DefaultVars
from build.pkg import package

package(name="xcb", package="xcb")
clibrary(name="clip_common", srcs=["./clip.cpp", "./image.cpp"])

clibrary(
    name="clip_none",
    srcs=["./clip_none.cpp"],
    hdrs=["./clip.h"],
    deps=["+clip_common"],
)

clibrary(
    name="clip_x11",
    srcs=["./clip_x11.cpp"],
    hdrs=["./clip.h"],
    deps=["+clip_common", "+xcb"],
)

clibrary(
    name="clip_osx",
    srcs=["./clip_osx.mm"],
    hdrs=["./clip.h"],
    deps=["+clip_common"],
)
