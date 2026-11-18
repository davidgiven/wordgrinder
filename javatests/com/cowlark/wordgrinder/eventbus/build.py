from build.junit4 import junit4
from build.utils import itemsof

junit4(
    name="test",
    srcitems=itemsof("javatests/com/cowlark/wordgrinder/eventbus/*.java", cwd=""),
    deps=["java/com/cowlark/wordgrinder/eventbus"],
)
