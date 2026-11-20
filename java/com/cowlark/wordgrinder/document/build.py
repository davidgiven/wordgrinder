from build.java import javalibrary

javalibrary(
    name="document",
    srcitems={
        f"com/cowlark/wordgrinder/document/{f}": f"./{f}"
        for f in [
            "DocumentStyle.java",
            "GlobalSettings.java",
        ]
    },
    deps=[
        "java/com/cowlark/wordgrinder+jspecify",
        "java/com/cowlark/wordgrinder/nativeinterface",
        "java/com/cowlark/wordgrinder/fileio",
        "java/com/cowlark/wordgrinder/addons/debug+settings",
        "java/com/cowlark/wordgrinder/addons/directories+settings",
        "java/com/cowlark/wordgrinder/addons/gui+settings",
        "java/com/cowlark/wordgrinder/addons/lookandfeel+settings",
        "java/com/cowlark/wordgrinder/addons/recents+settings",
        "java/com/cowlark/wordgrinder/addons/spillchocker+settings",
    ],
)
