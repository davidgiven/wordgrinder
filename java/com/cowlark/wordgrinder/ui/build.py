from build.java import javalibrary

from java.com.cowlark.wordgrinder.build import GUAVA_DEPS

javalibrary(
    name="menu-settings",
    srcitems={
        f"com/cowlark/wordgrinder/ui/{f}": f"./{f}"
        for f in ["MenuSettings.java"]
    },
    deps=["java/com/cowlark/wordgrinder/fileio"],
)

javalibrary(
    name="ui",
    srcitems={
        f"com/cowlark/wordgrinder/ui/{f}": f"./{f}"
        for f in [
            "Action.java",
            "Palette.java",
            "DarkPalette.java",
            "LightPalette.java",
            "ClassicPalette.java",
            "Ui.java",
            "Form.java",
            "Menu.java",
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
        "java/com/cowlark/wordgrinder/utils",
        "java/com/cowlark/wordgrinder/document",
        "java/com/cowlark/wordgrinder/eventbus",
        "java/com/cowlark/wordgrinder/nativeinterface",
        "third_party+org_jspecify_jspecify",
    ],
)
