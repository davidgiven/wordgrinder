from build.ab2 import DefaultVars
from build.c import clibrary
from build.windows import windres

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
