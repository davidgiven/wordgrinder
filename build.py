from build.ab2 import export
from build.pkg import has_package
from config import TEST_BINARY
import platform

osx = platform.system() == "Darwin"
windows = platform.system() == "Windows"

export(
    name="all",
    items={
        "bin/wordgrinder": TEST_BINARY,
    }
    | (
        {"bin/xwordgrinder": "src/c+wordgrinder-glfw-x11"}
        if has_package("xcb") and not osx
        else {}
    )
    | (
        {"bin/wordgrinder-osx": "src/c+wordgrinder-glfw-osx"}
        if osx
        else {}
    )
    | (
        {"bin/wordgrinder-windows": "src/c+wordgrinder-glfw-windows"}
        if windows
        else {}
    ),
    deps=["tests", "src/lua+typecheck"],
)
