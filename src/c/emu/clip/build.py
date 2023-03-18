from build.c import clibrary

clibrary(
    name="clip_none", srcs=["./clip.cpp", "./clip_none.cpp"], hdrs=["./clip.h"]
)
