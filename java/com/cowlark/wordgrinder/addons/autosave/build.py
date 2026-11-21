from build.java import javalibrary

javalibrary(
    name="settings",
    srcitems={
        f"com/cowlark/wordgrinder/addons/autosave/{f}": f"./{f}"
        for f in [
            "AutosaveDocumentSetSettings.java",
        ]
    },
    deps=["java/com/cowlark/wordgrinder/fileio", "third_party+org_jspecify_jspecify"],
)
