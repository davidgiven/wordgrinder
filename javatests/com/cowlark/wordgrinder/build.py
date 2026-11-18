from build.junit4 import junit4


junit4(
    name="word-test",
    srcitems={
        f"com/cowlark/wordgrinder/{f}": f"./{f}"
        for f in ["WordTest.java"]
    },
    deps=["java/com/cowlark/wordgrinder+main"],
)
