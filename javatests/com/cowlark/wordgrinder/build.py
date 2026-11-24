from build.junit4 import junit4
from java.com.cowlark.wordgrinder.build import GUAVA_DEPS

junit4(
    name="main-test",
    srcitems={
        f"com/cowlark/wordgrinder/{f}": f"./{f}"
        for f in ["MainTest.java"]
    },
    deps=GUAVA_DEPS + [
        "java/com/cowlark/wordgrinder/utils",
        "java/com/cowlark/wordgrinder+main",
        "java/com/cowlark/wordgrinder+build-info",
        "java/com/cowlark/wordgrinder/document",
        "java/com/cowlark/wordgrinder/nativeinterface",
        "java/com/cowlark/wordgrinder/eventbus",
    ],
)
