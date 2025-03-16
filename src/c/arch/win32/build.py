from build.ab import simplerule
from build.c import clibrary
from build.windows import windres, makensis
from config import VERSION
from glob import glob

windres(
    name="rc",
    srcs=[
        "./wordgrinder.rc",
    ],
    deps=["./manifest.xml", "./icon.ico"],
)

clibrary(
    name="win32",
    srcs=[".+rc"],
)

simplerule(
    name="wordgrinder-stripped",
    ins=["src/c+wordgrinder-wincon"],
    outs=["=wordgrinder-stripped.exe"],
    commands=["strip $[ins[0]] -o $[outs[0]]"],
    label="STRIP",
)

simplerule(
    name="wordgrinder-windows-stripped",
    ins=["src/c+wordgrinder-glfw-windows"],
    outs=["=wordgrinder-windows-stripped.exe"],
    commands=["strip $[ins[0]] -o $[outs[0]]"],
    label="STRIP",
)

makensis(
    name="installer",
    srcs=["extras/windows-installer.nsi"],
    deps=[
        ".+wordgrinder-stripped",
        ".+wordgrinder-windows-stripped",
        "README.wg",
        "extras/british.dictionary",
        "extras/american-canadian.dictionary",
    ]
    + glob("licenses/COPYING.*"),
    defs={"VERSION": VERSION},
)
