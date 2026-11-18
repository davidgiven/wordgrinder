from build.java import javalibrary

javalibrary(
    name="settings",
    srcitems={
        f"com/cowlark/wordgrinder/addons/scrapbook/{f}": f"./{f}"
        for f in [
            "ScrapbookDocumentSetSettings.java",
        ]
    },
    deps=["java/com/cowlark/wordgrinder/fileio", "java/com/cowlark/wordgrinder+jspecify"],
)
