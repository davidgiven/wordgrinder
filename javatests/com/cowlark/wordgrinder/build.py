from build.java import javalibrary, mavenjar
from build.utils import itemsof, test

mavenjar(name="junit", artifact="junit:junit:4.13.2")
mavenjar(name="hamcrest", artifact="org.hamcrest:hamcrest-core:1.3")

javalibrary(
    name="tests",
    srcitems=itemsof("javatests/com/cowlark/wordgrinder/*.java", cwd=""),
    deps=["java/com/cowlark/wordgrinder+main", ".+junit", ".+hamcrest"],
)

test(
    name="test",
    ins=[
        ".+tests",
        "java/com/cowlark/wordgrinder+main",
        "java/com/cowlark/wordgrinder+jspecify",
        ".+junit",
        ".+hamcrest",
    ],
    commands=[
        "$(JAVA) -cp '$[\":\".join(filenamesof(ins))]' "
        "org.junit.runner.JUnitCore com.cowlark.wordgrinder.WordTest",
    ],
)
