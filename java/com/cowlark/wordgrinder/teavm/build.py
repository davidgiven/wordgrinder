from build.ab import simplerule
from build.java import javalibrary

# This extension runs inside the compiler, not inside the application.
javalibrary(
    name="classes",
    srcitems={
        f"com/cowlark/wordgrinder/teavm/{f}": f"./{f}"
        for f in [
            "DumpableReflectionPolicy.java",
        ]
    },
    deps=[
        "java/com/cowlark/wordgrinder+teavm-extension-apis",
        "java/com/cowlark/wordgrinder+teavm-extension-spi",
        "java/com/cowlark/wordgrinder+teavm-extension-spi-util",
    ],
)

simplerule(
    name="teavm",
    ins=[
        ".+classes",
        "./META-INF/services/org.teavm.extension.spi.reflection.ReflectionPolicy",
    ],
    outs=["=reflection-policy.jar"],
    commands=[
        "cp $[ins[0]] $[outs[0]]",
        "$(JAR) --update --file=$[outs[0]] "
        "-C java/com/cowlark/wordgrinder/teavm "
        "META-INF/services/org.teavm.extension.spi.reflection.ReflectionPolicy",
    ],
    label="JAR",
)
