from build.ab2 import export
from build.pkg import has_package
from config import TEST_BINARY
import platform

export(
    name="all",
    items={
        "bin/wordgrinder": TEST_BINARY,
    }
    | (
        {"bin/xwordgrinder": "src/c+wordgrinder-glfw-x11"}
        if has_package("xcb")
        else {}
    )
    | (
        {"bin/wordgrinder-osx": "src/c+wordgrinder-glfw-osx"}
        if platform.system() == "Darwin"
        else {}
    ),
    deps=["tests", "src/lua+typecheck"],
)
