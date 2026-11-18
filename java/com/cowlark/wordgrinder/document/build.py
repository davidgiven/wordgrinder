from build.java import javalibrary

javalibrary(
    name="document",
    srcitems={
        f"com/cowlark/wordgrinder/document/{f}": f"./{f}"
        for f in [
            "DocumentStyle.java",
            "GlobalSettings.java",
        ]
    },
    deps=["java/com/cowlark/wordgrinder+jspecify", "java/com/cowlark/wordgrinder/fileio"],
)
