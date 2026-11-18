from build.java import javalibrary

javalibrary(
    name="settings",
    srcitems={
        f"com/cowlark/wordgrinder/addons/statusbar_pagecount/{f}": f"./{f}"
        for f in [
            "StatusbarPageCountDocumentSetSettings.java",
        ]
    },
    deps=["java/com/cowlark/wordgrinder/fileio"],
)
