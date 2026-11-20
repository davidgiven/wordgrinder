from build.junit4 import junit4

from java.com.cowlark.wordgrinder.build import GUAVA_DEPS

junit4(
    name="word-test",
    srcitems={
        f"com/cowlark/wordgrinder/{f}": f"./{f}"
        for f in ["WordTest.java"]
    },
    deps=[
        "java/com/cowlark/wordgrinder+text",
        "java/com/cowlark/wordgrinder/nativeinterface",
        "java/com/cowlark/wordgrinder+jspecify",
    ],
)

junit4(
    name="paragraph-test",
    srcitems={
        f"com/cowlark/wordgrinder/{f}": f"./{f}"
        for f in ["ParagraphTest.java"]
    },
    deps=GUAVA_DEPS + [
        "java/com/cowlark/wordgrinder+text",
        "java/com/cowlark/wordgrinder/document",
        "java/com/cowlark/wordgrinder/eventbus",
        "java/com/cowlark/wordgrinder/nativeinterface",
    ],
)

junit4(
    name="paragraph-render-test",
    srcitems={
        f"com/cowlark/wordgrinder/{f}": f"./{f}"
        for f in ["ParagraphRenderTest.java"]
    },
    deps=GUAVA_DEPS + [
        "java/com/cowlark/wordgrinder+text",
        "java/com/cowlark/wordgrinder/document",
        "java/com/cowlark/wordgrinder/eventbus",
        "java/com/cowlark/wordgrinder/nativeinterface",
        "java/com/cowlark/wordgrinder+jspecify",
    ],
)
