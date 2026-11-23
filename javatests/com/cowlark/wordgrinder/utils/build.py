from build.junit4 import junit4

junit4(
    name="argument-parser-test",
    srcitems={
        f"com/cowlark/wordgrinder/utils/{f}": f"./{f}"
        for f in ["ArgumentParserTest.java"]
    },
    deps=["java/com/cowlark/wordgrinder/utils"],
)

junit4(
    name="injector-test",
    srcitems={
        f"com/cowlark/wordgrinder/utils/{f}": f"./{f}"
        for f in ["InjectorTest.java"]
    },
    deps=["java/com/cowlark/wordgrinder/utils"],
)
