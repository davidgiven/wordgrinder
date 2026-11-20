from build.java import javalibrary

javalibrary(
    name="forms",
    srcitems={
        f"com/cowlark/wordgrinder/forms/{f}": f"./{f}"
        for f in [
            "Widget.java",
            "DividerWidget.java",
            "LabelWidget.java",
            "CheckboxWidget.java",
            "ToggleWidget.java",
            "TextFieldWidget.java",
            "BrowserWidget.java",
        ]
    },
    deps=[
        "java/com/cowlark/wordgrinder+main",
        "java/com/cowlark/wordgrinder+jspecify",
    ],
)
