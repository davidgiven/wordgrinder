from build.java import javalibrary

javalibrary(
    name="settings",
    srcitems={
        f"com/cowlark/wordgrinder/addons/lookandfeel/{f}": f"./{f}"
        for f in [
            "LookAndFeelGlobalSettings.java",
        ]
    },
    deps=["java/com/cowlark/wordgrinder/fileio", "java/com/cowlark/wordgrinder+jspecify"],
)
