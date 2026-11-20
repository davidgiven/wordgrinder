from build.junit4 import junit4

junit4(
    name="widget-test",
    srcitems={
        f"com/cowlark/wordgrinder/forms/{f}": f"./{f}"
        for f in ["WidgetTest.java"]
    },
    deps=[
        "java/com/cowlark/wordgrinder/forms",
        "java/com/cowlark/wordgrinder+main",
    ],
)
