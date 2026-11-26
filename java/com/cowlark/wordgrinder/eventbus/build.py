from build.java import javalibrary

javalibrary(
    name="eventbus",
    srcitems={
        f"com/cowlark/wordgrinder/eventbus/{f}": f"./{f}"
        for f in [
            "BuildStatusBarEvent.java",
            "DrawWordEvent.java",
            "ChangedEvent.java",
            "WaitingForUserEvent.java",
            "IdleEvent.java",
            "KeyTypedEvent.java",
            "MovedEvent.java",
            "RedrawEvent.java",
            "Event.java",
            "EventBus.java",
            "EventCallback.java",
            "EventToken.java",
        ]
    },
    deps=["java/com/cowlark/wordgrinder/utils", "third_party+org_jspecify_jspecify"],
)
