from build.junit4 import junit4
from java.com.cowlark.wordgrinder.build import GUAVA_DEPS

junit4(
    name="word-processor-test",
    srcitems={
        f"com/cowlark/wordgrinder/app/{f}": f"./{f}"
        for f in ["WordProcessorTest.java"]
    },
    deps=GUAVA_DEPS + [
        "java/com/cowlark/wordgrinder/app",
        "java/com/cowlark/wordgrinder/document",
        "java/com/cowlark/wordgrinder/nativeinterface",
        "java/com/cowlark/wordgrinder/eventbus",
        "java/com/cowlark/wordgrinder/ui",
    ],
)
