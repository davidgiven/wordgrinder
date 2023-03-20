from build.c import clibrary

clibrary(
    name="minizip",
    srcs=[
        "./ioapi.c",
        "./unzip.c",
        "./zip.c",
    ],
    hdrs=["./zip.h", "./unzip.h"],
    exportvars={"+ldflags": ["-lz"]},
)
