from build.java import javalibrary
from build.utils import itemsof

javalibrary(
    name="document",
    srcitems=itemsof("java/com/cowlark/wordgrinder/document/*.java", cwd=""),
    deps=["java/com/cowlark/wordgrinder+jspecify"],
)
