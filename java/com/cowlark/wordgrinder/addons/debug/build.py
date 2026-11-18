from build.java import javalibrary

javalibrary(
    name="settings",
    srcitems={
        f"com/cowlark/wordgrinder/addons/debug/{f}": f"./{f}"
        for f in [
            "DebugGlobalSettings.java",
        ]
    },
    deps=["java/com/cowlark/wordgrinder/fileio"],
)
