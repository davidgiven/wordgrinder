from build.java import javalibrary

from java.com.cowlark.wordgrinder.build import GUAVA_DEPS

javalibrary(
    name="ui",
    srcitems={
        f"com/cowlark/wordgrinder/ui/{f}": f"./{f}"
        for f in [
            "Palette.java",
            "DarkPalette.java",
            "LightPalette.java",
            "ClassicPalette.java",
            "Ui.java",
            "Form.java",
            "Widget.java",
            "DividerWidget.java",
            "LabelWidget.java",
            "WrappedLabelWidget.java",
            "CheckboxWidget.java",
            "ToggleWidget.java",
            "TextFieldWidget.java",
            "BrowserWidget.java",
        ]
    },
    deps=GUAVA_DEPS + [
        "java/com/cowlark/wordgrinder/document",
        "java/com/cowlark/wordgrinder/eventbus",
        "java/com/cowlark/wordgrinder/nativeinterface",
        "java/com/cowlark/wordgrinder+jspecify",
    ],
)
