from build.ab2 import export
from build.pkg import has_package
from config import TEST_BINARY, VERSION
import platform

osx = platform.system() == "Darwin"
windows = platform.system() == "Windows"
haiku = platform.system() == "Haiku"

has_xwordgrinder = has_package("xcb") and not osx

export(
    name="binaries",
    items={
        "bin/wordgrinder": TEST_BINARY,
    }
    | (
        {"bin/xwordgrinder": "src/c+wordgrinder-glfw-x11"}
        if has_xwordgrinder
        else {}
    )
    | ({"bin/wordgrinder-osx": "src/c+wordgrinder-glfw-osx"} if osx else {})
    | (
        {"bin/wordgrinder-windows": "src/c+wordgrinder-glfw-windows"}
        if windows
        else {}
    )
    | (
        {"bin/wordgrinder-haiku": "src/c+wordgrinder-glfw-haiku"}
        if haiku
        else {}
    ),
)

export(
    name="all",
    items=(
        (
            {
                f"bin/WordGrinder-{VERSION}-setup.exe": "src/c/arch/win32+installer"
            }
            if windows
            else {}
        )
        | (
            {f"bin/xwordgrinder.1": "extras+xwordgrinder.1"}
            if has_xwordgrinder
            else {}
        )
        | ({"bin/wordgrinder.1": "extras+wordgrinder.1"} if not windows else {})
    ),
    deps=["tests", "src/lua+typecheck", "+binaries"],
)
