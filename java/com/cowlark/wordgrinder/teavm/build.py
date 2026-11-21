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
        "third_party+org_teavm_teavm_extension_apis",
        "third_party+org_teavm_teavm_extension_spi",
        "third_party+org_teavm_teavm_extension_spi_util",
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
