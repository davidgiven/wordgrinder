from build.ab2 import DefaultVars
from build.c import clibrary
from build.windows import windres, makensis
from config import VERSION

windres(
    name="rc",
    srcs=[
        "./wordgrinder.rc",
    ],
    deps = [
        "./manifest.xml"
    ]
)

clibrary(
    name="win32",
    srcs=[
        "+rc"
    ],
)

makensis(
    name="installer",
    srcs=["extras/windows-installer.nsi"],
    deps=[
        "bin/wordgrinder",
        "bin/wordgrinder-windows"
    ],
    defs={
        "VERSION": VERSION
    }
)
