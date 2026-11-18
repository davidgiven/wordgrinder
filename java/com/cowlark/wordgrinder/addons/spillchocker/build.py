from build.java import javalibrary

javalibrary(
    name="settings",
    srcitems={
        f"com/cowlark/wordgrinder/addons/spillchocker/{f}": f"./{f}"
        for f in [
            "SpillchockerDocumentSetSettings.java",
            "SpillchockerGlobalSettings.java",
        ]
    },
    deps=["java/com/cowlark/wordgrinder/fileio", "java/com/cowlark/wordgrinder+jspecify"],
)
