from build.java import javalibrary
from java.com.cowlark.wordgrinder.build import GUAVA_DEPS

javalibrary(
    name="utils",
    srcitems={
        f"com/cowlark/wordgrinder/utils/{f}": f"./{f}"
        for f in ["ArgumentParser.java"]
    },
    deps=GUAVA_DEPS,
)
