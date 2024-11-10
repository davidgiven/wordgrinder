from build.ab import export
from config import (
    TEST_BINARY,
    VERSION,
    BUILDTYPE,
    HAS_OSX,
    HAS_NCURSES,
    HAS_XWORDGRINDER,
    HAS_HAIKU,
    IS_WINDOWS,
)

export(
    name="all",
    items={
        "bin/wordgrinder$(EXT)": TEST_BINARY,
    }
    | ({"bin/xwordgrinder": "src/c+wordgrinder-glfw-x11"} if HAS_XWORDGRINDER else {})
    | (
        {"bin/wordgrinder-haiku": "src/c+wordgrinder-glfw-haiku"}
        if HAS_HAIKU
        else {}
    )
    | (
        {
            "bin/wordgrinder-osx": "src/c+wordgrinder-glfw-osx",
            "bin/wordgrinder-osx-ncurses": "src/c+wordgrinder-ncurses",
            f"bin/WordGrinder-{VERSION}-setup.pkg": "src/c+wordgrinder_pkg",
        }
        if HAS_OSX
        else {}
    )
    | (
        {
            "bin/wordgrinder-windows$(EXT)": "src/c+wordgrinder-glfw-windows",
            "bin/wordgrinder-wincon$(EXT)": "src/c+wordgrinder-wincon",
            f"bin/WordGrinder-{VERSION}-setup.exe": "src/c/arch/win32+installer",
        }
        if IS_WINDOWS
        else {}
    )
    | (
        {f"bin/xwordgrinder.1": "extras+xwordgrinder.1"}
        if BUILDTYPE in {"unix", "osx"}
        else {}
    )
    | (
        {"bin/wordgrinder.1": "extras+wordgrinder.1"}
        if BUILDTYPE in {"unix", "osx"}
        else {}
    ),
    deps=["tests", "src/lua+typecheck"],
)
