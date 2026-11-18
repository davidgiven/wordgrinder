from build.java import javalibrary

javalibrary(
    name="settings",
    srcitems={
        f"com/cowlark/wordgrinder/addons/autosave/{f}": f"./{f}"
        for f in [
            "AutosaveDocumentSetSettings.java",
        ]
    },
    deps=["java/com/cowlark/wordgrinder/fileio", "java/com/cowlark/wordgrinder+jspecify"],
)
