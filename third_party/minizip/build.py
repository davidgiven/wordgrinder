from build.ab2 import DefaultVars
from build.c import clibrary
from build.pkg import package

package(name="zlib", package="zlib")

clibrary(
    name="minizip",
    srcs=[
        "./ioapi.c",
        "./unzip.c",
        "./zip.c",
    ],
    hdrs=["./zip.h", "./unzip.h"],
    deps=["+zlib"],
    vars=DefaultVars + {"+cflags": ["-DNOCRYPT"]},
)
