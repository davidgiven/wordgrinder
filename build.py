from build.ab import export
from config import TEST_BINARY, VERSION, BUILDTYPE

export(
    name="binaries",
    items={
        "bin/wordgrinder$(EXT)": TEST_BINARY,
    }
    | (
        {"bin/xwordgrinder": "src/c+wordgrinder-glfw-x11"}
        if BUILDTYPE == "unix"
        else {}
    )
    | (
        {"bin/wordgrinder-haiku": "src/c+wordgrinder-glfw-haiku"}
        if BUILDTYPE == "haiku"
        else {}
    )
    | (
        {"bin/wordgrinder-osx": "src/c+wordgrinder-glfw-osx"}
        if BUILDTYPE == "osx"
        else {}
    )
    | (
        {"bin/wordgrinder-windows$(EXT)": "src/c+wordgrinder-glfw-windows"}
        if BUILDTYPE == "windows"
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
            if BUILDTYPE == "windows"
            else {}
        )
        | (
            {f"bin/WordGrinder-{VERSION}-setup.pkg": "src/c+wordgrinder_pkg"}
            if BUILDTYPE == "osx"
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
        )
    ),
    deps=["tests", "src/lua+typecheck", "+binaries"],
)
