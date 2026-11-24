from build.java import javalibrary
from java.com.cowlark.wordgrinder.build import GUAVA_DEPS

javalibrary(
    name="app",
    srcitems={
        f"com/cowlark/wordgrinder/app/{f}": f"./{f}"
        for f in ["MenuDefinitions.java", "Navigation.java", "WordProcessor.java"]
    },
    deps=GUAVA_DEPS + [
        "java/com/cowlark/wordgrinder/document",
        "java/com/cowlark/wordgrinder/nativeinterface",
        "java/com/cowlark/wordgrinder/eventbus",
        "java/com/cowlark/wordgrinder/ui",
        "java/com/cowlark/wordgrinder/utils",
        "java/com/cowlark/wordgrinder/addons/undo",
    ],
)
