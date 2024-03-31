from build.ab import export
from config import TEST_BINARY, VERSION, BUILD_TYPE

export(
    name="binaries",
    items={
        "bin/wordgrinder": TEST_BINARY,
    }
    | (
        {"bin/xwordgrinder": "src/c+wordgrinder-glfw-x11"}
        if BUILD_TYPE == "unix"
        else {}
    )
    | ({"bin/wordgrinder-osx": "src/c+wordgrinder-osx"} if BUILD_TYPE == "osx" else {})
    | (
        {"bin/wordgrinder-windows": "src/c+wordgrinder-glfw-windows"}
        if BUILD_TYPE == "windows"
        else {}
    )
)

export(
    name="all",
    items=(
        (
            {
                f"bin/WordGrinder-{VERSION}-setup.exe": "src/c/arch/win32+installer"
            }
            if BUILD_TYPE == "windows"
            else {}
        )
        | (
            {f"bin/xwordgrinder.1": "extras+xwordgrinder.1"}
            if BUILD_TYPE in {"unix", "osx"}
            else {}
        )
        | ({"bin/wordgrinder.1": "extras+wordgrinder.1"} if BUILD_TYPE in {"unix", "osx"} else {})
    ),
    deps=["tests", "src/lua+typecheck", "+binaries"],
)
