from build.c import cxxlibrary
from build.java import javalibrary

# Java bindings shared by the application and form widgets.
javalibrary(
    name="nativeinterface",
    srcitems={
        f"com/cowlark/wordgrinder/nativeinterface/{f}": f"./{f}"
        for f in ["Clipboard.java", "Display.java", "Screen.java"]
    },
    deps=["java/com/cowlark/wordgrinder+teavm-interop"],
)

# C ABI adapters for the existing display and clipboard backends.
cxxlibrary(
    name="native",
    srcs=["./display.cc", "./clipboard.cc"],
    hdrs={"display.h": "./display.h", "clipboard.h": "./clipboard.h"},
    deps=["src/c/arch/ncurses", "third_party/clip+clip_none"],
)
