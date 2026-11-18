from build.java import javalibrary
from build.utils import itemsof

javalibrary(
    name="eventbus",
    srcitems=itemsof("java/com/cowlark/wordgrinder/eventbus/*.java", cwd=""),
    deps=["java/com/cowlark/wordgrinder+jspecify"],
)
