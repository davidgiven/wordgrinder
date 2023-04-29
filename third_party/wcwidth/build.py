from build.ab2 import DefaultVars
from build.c import clibrary

clibrary(
    name="wcwidth",
    srcs=["./wcwidth.cc"],
)

