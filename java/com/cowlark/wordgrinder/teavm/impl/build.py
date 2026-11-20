from build.c import cxxlibrary
from build.java import javalibrary

# TeaVM implementations of the backend-independent native interfaces.
javalibrary(
    name="impl",
    srcitems={
        f"com/cowlark/wordgrinder/teavm/impl/{f}": f"./{f}"
        for f in [
            "CString.java",
            "ClipboardImpl.java",
            "DisplayImpl.java",
            "ScreenImpl.java",
            "SystemImpl.java",
        ]
    },
    deps=[
        "java/com/cowlark/wordgrinder/nativeinterface",
        "java/com/cowlark/wordgrinder+jspecify",
        "java/com/cowlark/wordgrinder+teavm-interop",
        "java/com/cowlark/wordgrinder+teavm-core",
    ],
)

# C ABI adapters used exclusively by the TeaVM implementations.
cxxlibrary(
    name="native",
    srcs=["./display.cc", "./clipboard.cc", "./system.cc"],
    hdrs={
        "display.h": "./display.h",
        "clipboard.h": "./clipboard.h",
        "system.h": "./system.h",
    },
    deps=["src/c/arch/ncurses", "third_party/clip+clip_none"],
)
