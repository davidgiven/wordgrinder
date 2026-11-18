from build.java import javalibrary, javaprogram


javalibrary(
    name="main",
    srcitems={
        "com/cowlark/wordgrinder/Main.java": "./Main.java",
    },
)

javaprogram(
    name="wordgrinder",
    mainclass="com.cowlark.wordgrinder.Main",
    deps=[".+main"],
)
