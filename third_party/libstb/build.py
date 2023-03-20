from build.ab2 import DefaultVars
from build.c import clibrary

clibrary(
    name="libstb",
    srcs=["./stb.c"],
    hdrs=["./stb_ds.h", "./stb_rect_pack.h", "./stb_truetype.h"],
)
