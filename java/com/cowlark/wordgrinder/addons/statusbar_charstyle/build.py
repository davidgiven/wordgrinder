from build.java import javalibrary

javalibrary(
    name="statusbar_charstyle",
    srcitems={
        f"com/cowlark/wordgrinder/addons/statusbar_charstyle/{f}": f"./{f}"
        for f in ["StatusbarCharStyleAddon.java"]
    },
    deps=[
        "java/com/cowlark/wordgrinder/document",
        "java/com/cowlark/wordgrinder/eventbus",
    ],
)
