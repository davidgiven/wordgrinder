from build.junit4 import junit4

junit4(
    name="widget-test",
    srcitems={
        f"com/cowlark/wordgrinder/ui/{f}": f"./{f}"
        for f in ["WidgetTest.java", "TestScreen.java"]
    },
    deps=[
        "java/com/cowlark/wordgrinder/ui",
        "java/com/cowlark/wordgrinder/nativeinterface",
    ],
)

junit4(
    name="ui-test",
    srcitems={
        f"com/cowlark/wordgrinder/ui/{f}": f"./{f}"
        for f in ["UiTest.java", "TestScreen.java"]
    },
    deps=[
        "java/com/cowlark/wordgrinder/ui",
        "java/com/cowlark/wordgrinder/nativeinterface",
        "java/com/cowlark/wordgrinder+jspecify",
    ],
)

junit4(
    name="form-test",
    srcitems={
        f"com/cowlark/wordgrinder/ui/{f}": f"./{f}"
        for f in ["FormTest.java", "TestScreen.java"]
    },
    deps=[
        "java/com/cowlark/wordgrinder/ui",
        "java/com/cowlark/wordgrinder/nativeinterface",
        "java/com/cowlark/wordgrinder+jspecify",
    ],
)

junit4(
    name="wrapped-label-test",
    srcitems={
        f"com/cowlark/wordgrinder/ui/{f}": f"./{f}"
        for f in ["WrappedLabelWidgetTest.java", "TestScreen.java"]
    },
    deps=[
        "java/com/cowlark/wordgrinder/ui",
        "java/com/cowlark/wordgrinder/document",
        "java/com/cowlark/wordgrinder/eventbus",
        "java/com/cowlark/wordgrinder/nativeinterface",
        "java/com/cowlark/wordgrinder+jspecify",
    ],
)
