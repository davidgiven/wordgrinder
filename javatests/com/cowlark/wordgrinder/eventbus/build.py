from build.junit4 import junit4


junit4(
    name="eventbus-test",
    srcitems={
        f"com/cowlark/wordgrinder/eventbus/{f}": f"./{f}"
        for f in ["EventBusTest.java"]
    },
    deps=["java/com/cowlark/wordgrinder/eventbus"],
)
