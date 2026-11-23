from build.java import javalibrary

javalibrary(
    name="undo",
    srcitems={
        f"com/cowlark/wordgrinder/addons/undo/{f}": f"./{f}"
        for f in [
            "CheckpointAction.java",
            "UndoAddon.java",
        ]
    },
    deps = ["java/com/cowlark/wordgrinder/ui"]
)
