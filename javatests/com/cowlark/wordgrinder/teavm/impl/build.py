from build.ab import filenameof, simplerule
from build.java import javalibrary
from build.junit4 import junit4
from java.com.cowlark.wordgrinder.build import teavm_native

# Reuse the application's compiler/runtime classpath for the native interop probe.
teavm_native.materialise()
compiler_deps = teavm_native.deps

javalibrary(
    name="cstring-probe-classes",
    srcitems={
        f"com/cowlark/wordgrinder/teavm/impl/{f}": f"./{f}"
        for f in ["CStringProbe.java"]
    },
    deps=[
        "java/com/cowlark/wordgrinder/teavm/impl",
        "java/com/cowlark/wordgrinder/nativeinterface",
        "java/com/cowlark/wordgrinder+teavm-interop",
        "java/com/cowlark/wordgrinder+jspecify",
    ],
)

# Compile the real bindings against assertion stubs rather than a terminal or clipboard.
probe = simplerule(
    name="cstring-probe",
    ins=[
        ".+cstring-probe-classes",
        "./cstring-probe.c",
        "./cstring-probe.h",
        "java/com/cowlark/wordgrinder/teavm/impl/display.h",
        "java/com/cowlark/wordgrinder/teavm/impl/clipboard.h",
        "java/com/cowlark/wordgrinder/teavm/impl/system.cc",
        "java/com/cowlark/wordgrinder/teavm/impl/system.h",
    ],
    deps=compiler_deps,
    outs=["=cstring-probe$(EXT)"],
    commands=[
        "$(JAVA) -cp '$[\":\".join(filenamesof(deps))]' "
        "org.teavm.cli.TeaVMRunner -t c -d $[dir]/c "
        "-p $[ins[0]] $[deps] -- com.cowlark.wordgrinder.teavm.impl.CStringProbe",
        "$(CXX) $(CXXFLAGS) -c -o $[dir]/system.o $[ins[5]]",
        "$(CC) $(CFLAGS) -UNDEBUG -std=c11 "
        "-Ijava/com/cowlark/wordgrinder/teavm/impl "
        "-Ijavatests/com/cowlark/wordgrinder/teavm/impl "
        "$[dir]/c/all.c $[ins[1]] $[dir]/system.o -lm -o $[outs[0]]",
    ],
    label="TEAVM",
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
        f"com/cowlark/wordgrinder/teavm/impl/{f}": f"./{f}"
        for f in ["CStringTest.java"]
    },
    deps=[resource],
)
