from build.java import javalibrary

javalibrary(
    name="settings",
    srcitems={
        f"com/cowlark/wordgrinder/addons/recents/{f}": f"./{f}"
        for f in [
            "RecentsGlobalSettings.java",
        ]
    },
    deps=["java/com/cowlark/wordgrinder+jspecify"],
)
