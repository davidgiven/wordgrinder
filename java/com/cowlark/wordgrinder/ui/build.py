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
            "BrowserWidget.java",
            "CheckboxWidget.java",
            "ClassicPalette.java",
            "DarkPalette.java",
            "DividerWidget.java",
            "Form.java",
            "LabelWidget.java",
            "LightPalette.java",
            "Menu.java",
            "MenuSettings.java",
            "MenuTree.java",
            "Palette.java",
            "TextFieldWidget.java",
            "ToggleWidget.java",
            "Ui.java",
            "Widget.java",
            "WrappedLabelWidget.java",
        ]
    },
    deps=GUAVA_DEPS + [
        "java/com/cowlark/wordgrinder/utils",
        "java/com/cowlark/wordgrinder/document",
        "java/com/cowlark/wordgrinder/eventbus",
        "java/com/cowlark/wordgrinder/fileio",
        "java/com/cowlark/wordgrinder/nativeinterface",
        "third_party+org_jspecify_jspecify",
    ],
)
