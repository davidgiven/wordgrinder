from build.java import javalibrary

javalibrary(
    name="settings",
    srcitems={
        f"com/cowlark/wordgrinder/addons/directories/{f}": f"./{f}"
        for f in [
            "DirectoriesGlobalSettings.java",
        ]
    },
    deps=["java/com/cowlark/wordgrinder/fileio", "java/com/cowlark/wordgrinder+jspecify"],
)
