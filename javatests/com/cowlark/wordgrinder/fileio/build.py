from build.junit4 import junit4


junit4(
    name="dumper-test",
    srcitems={
        f"com/cowlark/wordgrinder/fileio/{f}": f"./{f}"
        for f in ["DumperTest.java"]
    },
    deps=["java/com/cowlark/wordgrinder/fileio"],
)

junit4(
    name="undumper-test",
    srcitems={
        f"com/cowlark/wordgrinder/fileio/{f}": f"./{f}"
        for f in ["UndumperTest.java"]
    },
    deps=["java/com/cowlark/wordgrinder/fileio"],
)
