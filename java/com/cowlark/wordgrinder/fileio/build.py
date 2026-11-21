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
            "TMagic.java",
            "Undumper.java",
        ]
    },
    deps=["third_party+org_jspecify_jspecify"],
)
