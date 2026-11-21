from build.java import javalibrary

javalibrary(
    name="eventbus",
    srcitems={
        f"com/cowlark/wordgrinder/eventbus/{f}": f"./{f}"
        for f in [
            "DrawWord.java",
            "Changed.java",
            "WaitingForUser.java",
            "Idle.java",
            "KeyTyped.java",
            "Event.java",
            "EventBus.java",
            "EventCallback.java",
            "EventToken.java",
        ]
    },
    deps=["third_party+org_jspecify_jspecify"],
)
