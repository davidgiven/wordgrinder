from build.ab import filenameof, simplerule
from build.c import cprogram, cxxfile
from build.java import javalibrary, javaprogram
from build.junit4 import junit4

from java.com.cowlark.wordgrinder.build import (
    TEAVM_DRIVER_DEPS,
    TEAVM_DRIVER_MAIN,
    TEAVM_EXTERNAL_DEPS,
)

javalibrary(
    name="cstring-probe-classes",
    srcitems={
        f"com/cowlark/wordgrinder/nativeinterface/teavm/{f}": f"./{f}"
        for f in ["CStringProbe.java"]
    },
    deps=[
        "java/com/cowlark/wordgrinder/nativeinterface/teavm",
        "java/com/cowlark/wordgrinder/nativeinterface",
        "third_party+org_teavm_teavm_interop",
        "third_party+org_jspecify_jspecify",
    ],
)

# Include the application classes inspected by the shared reflection policy.
compiler = javaprogram(
    name="cstring-probe-compiler",
    mainclass=TEAVM_DRIVER_MAIN,
    deps=TEAVM_DRIVER_DEPS + [
        ".+cstring-probe-classes",
        "java/com/cowlark/wordgrinder+main",
    ],
)

# Generate a self-contained C translation unit for the TeaVM probe.
generated = simplerule(
    name="cstring-probe-generated",
    ins=[compiler],
    deps=TEAVM_EXTERNAL_DEPS,
    outs=["=cstring-probe-generated.c"],
    commands=["$[ins[0]] com.cowlark.wordgrinder.nativeinterface.teavm.CStringProbe $[outs[0]]"],
    label="TEAVM",
)

# Build the platform adapter with the C++ toolchain.
system = cxxfile(
    name="cstring-probe-system",
    srcs=["java/com/cowlark/wordgrinder/nativeinterface/teavm/system.cc"],
    deps=["java/com/cowlark/wordgrinder/nativeinterface/teavm/system.h"],
)

# Compile the real bindings against assertion stubs using the configured flags.
probe = cprogram(
    name="cstring-probe",
    srcs=[generated, "./cstring-probe.c", "./cstring-probe.h", system],
    deps=[
        "./cstring-probe.h",
        "java/com/cowlark/wordgrinder/nativeinterface/teavm+native"
    ],
    cflags=[
        "-UNDEBUG",
        "-std=c11",
    ],
    ldflags=["-lm"],
)

# Put the executable on the JUnit classpath as a resource, independent of sandbox paths.
resource = simplerule(
    name="cstring-probe-resource",
    ins=[probe],
    outs=["=cstring-probe.jar"],
    commands=[
        "mkdir -p $[dir]/resources",
        "cp $[ins[0]] $[dir]/resources/cstring-probe",
        "$(JAR) --create --file=$[outs[0]] -C $[dir]/resources cstring-probe",
    ],
    label="JAR",
)
resource.traits.add("externaljar")
resource.materialise()
resource.args["jar"] = filenameof(resource.outs[0])

junit4(
    name="cstring-test",
    srcitems={
        f"com/cowlark/wordgrinder/nativeinterface/teavm/{f}": f"./{f}"
        for f in ["CStringTest.java"]
    },
    deps=[resource],
)
