from build.java import javalibrary

javalibrary(
    name="settings",
    srcitems={
        f"com/cowlark/wordgrinder/addons/lookandfeel/{f}": f"./{f}"
        for f in [
            "LookAndFeelGlobalSettings.java",
        ]
    },
    deps=["java/com/cowlark/wordgrinder/fileio", "third_party+org_jspecify_jspecify"],
)
