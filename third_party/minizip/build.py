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
    hdrs={"zip.h": "./zip.h", "unzip.h": "./unzip.h", "ioapi.h": "./ioapi.h"},
    deps=[".+zlib"],
    cflags=["-DNOCRYPT"],
)
