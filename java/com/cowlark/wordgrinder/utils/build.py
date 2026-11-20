from build.java import javalibrary

javalibrary(
    name="utils",
    srcitems={
        f"com/cowlark/wordgrinder/utils/{f}": f"./{f}"
        for f in ["ArgumentParser.java"]
    },
    deps=["java/com/cowlark/wordgrinder+jspecify"],
)
