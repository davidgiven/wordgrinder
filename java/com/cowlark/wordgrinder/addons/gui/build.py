from build.java import javalibrary

javalibrary(
    name="settings",
    srcitems={
        f"com/cowlark/wordgrinder/addons/gui/{f}": f"./{f}"
        for f in [
            "GuiGlobalSettings.java",
        ]
    },
    deps=["java/com/cowlark/wordgrinder/fileio", "third_party+org_jspecify_jspecify"],
)
