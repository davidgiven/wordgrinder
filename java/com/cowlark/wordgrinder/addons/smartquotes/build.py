from build.java import javalibrary

javalibrary(
    name="settings",
    srcitems={
        f"com/cowlark/wordgrinder/addons/smartquotes/{f}": f"./{f}"
        for f in [
            "SmartQuotesDocumentSetSettings.java",
        ]
    },
    deps=["java/com/cowlark/wordgrinder/fileio", "third_party+org_jspecify_jspecify"],
)
