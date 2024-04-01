from build.ab import normalrule
from build.c import clibrary
from build.windows import windres, makensis
from config import VERSION

windres(
    name="rc",
    srcs=[
        "./wordgrinder.rc",
    ],
    deps=["./manifest.xml"],
)

clibrary(
    name="win32",
    srcs=[".+rc"],
)

normalrule(
    name="wordgrinder-stripped",
    ins=["src/c+wordgrinder-wincon"],
    outs=["wordgrinder-stripped.exe"],
    commands=["strip {ins[0]} -o {outs[0]}"],
    label="STRIP"
)

normalrule(
    name="wordgrinder-windows-stripped",
    ins=["src/c+wordgrinder-glfw-windows"],
    outs=["wordgrinder-windows-stripped.exe"],
    commands=["strip {ins[0]} -o {outs[0]}"],
    label="STRIP"
)

makensis(
    name="installer",
    srcs=["extras/windows-installer.nsi"],
    deps=[".+wordgrinder-stripped", ".+wordgrinder-windows-stripped"],
    defs={"VERSION": VERSION},
)
