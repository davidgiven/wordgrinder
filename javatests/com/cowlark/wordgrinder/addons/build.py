from build.junit4 import junit4

junit4(
    name="settings-test",
    srcitems={
        f"com/cowlark/wordgrinder/addons/{f}": f"./{f}"
        for f in ["SettingsTest.java"]
    },
    deps=[
        "java/com/cowlark/wordgrinder+jspecify",
        "java/com/cowlark/wordgrinder/fileio",
        "java/com/cowlark/wordgrinder/document",
        "java/com/cowlark/wordgrinder/addons/debug+settings",
        "java/com/cowlark/wordgrinder/addons/directories+settings",
        "java/com/cowlark/wordgrinder/addons/gui+settings",
        "java/com/cowlark/wordgrinder/addons/lookandfeel+settings",
        "java/com/cowlark/wordgrinder/addons/recents+settings",

        "java/com/cowlark/wordgrinder/addons/autosave+settings",
        "java/com/cowlark/wordgrinder/addons/scrapbook+settings",
        "java/com/cowlark/wordgrinder/addons/smartquotes+settings",
        "java/com/cowlark/wordgrinder/addons/spillchocker+settings",
        "java/com/cowlark/wordgrinder/addons/statusbar_pagecount+settings",
    ],
)
