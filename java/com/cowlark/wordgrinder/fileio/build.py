from build.java import javalibrary

javalibrary(
    name="fileio",
    srcitems={
        f"com/cowlark/wordgrinder/fileio/{f}": f"./{f}"
        for f in [
            "DumpFields.java",
            "Dumpable.java",
            "Dumper.java",
            "RemainingDumpables.java",
            "Undumper.java",
        ]
    },
    deps=["java/com/cowlark/wordgrinder+jspecify"],
)
