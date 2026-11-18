from build.ab import simplerule
from build.c import cxxlibrary, cxxprogram
from build.java import javalibrary, javaprogram, mavenjar

TEAVM_VERSION = "0.14.1"

mavenjar(name="teavm-cli", artifact=f"org.teavm:teavm-cli:{TEAVM_VERSION}")
mavenjar(
    name="teavm-tooling", artifact=f"org.teavm:teavm-tooling:{TEAVM_VERSION}"
)
mavenjar(name="teavm-core", artifact=f"org.teavm:teavm-core:{TEAVM_VERSION}")
mavenjar(
    name="teavm-classlib", artifact=f"org.teavm:teavm-classlib:{TEAVM_VERSION}"
)
mavenjar(
    name="teavm-platform", artifact=f"org.teavm:teavm-platform:{TEAVM_VERSION}"
)
mavenjar(
    name="teavm-interop", artifact=f"org.teavm:teavm-interop:{TEAVM_VERSION}"
)


mavenjar(
    name="teavm-relocated-libs-commons-cli",
    artifact=f"org.teavm:teavm-relocated-libs-commons-cli:{TEAVM_VERSION}",
)

mavenjar(
    name="teavm-metaprogramming-api",
    artifact=f"org.teavm:teavm-metaprogramming-api:{TEAVM_VERSION}",
)

mavenjar(
    name="teavm-relocated-libs-asm-commons",
    artifact=f"org.teavm:teavm-relocated-libs-asm-commons:{TEAVM_VERSION}",
)

mavenjar(
    name="teavm-relocated-libs-asm-util",
    artifact=f"org.teavm:teavm-relocated-libs-asm-util:{TEAVM_VERSION}",
)

mavenjar(
    name="teavm-relocated-libs-hppc",
    artifact=f"org.teavm:teavm-relocated-libs-hppc:{TEAVM_VERSION}",
)

mavenjar(
    name="teavm-relocated-libs-rhino",
    artifact=f"org.teavm:teavm-relocated-libs-rhino:{TEAVM_VERSION}",
)

mavenjar(
    name="teavm-relocated-libs-commons-io",
    artifact=f"org.teavm:teavm-relocated-libs-commons-io:{TEAVM_VERSION}",
)

mavenjar(
    name="teavm-jso-apis",
    artifact=f"org.teavm:teavm-jso-apis:{TEAVM_VERSION}",
)

mavenjar(
    name="teavm-jso-impl",
    artifact=f"org.teavm:teavm-jso-impl:{TEAVM_VERSION}",
)

mavenjar(
    name="teavm-metaprogramming-impl",
    artifact=f"org.teavm:teavm-metaprogramming-impl:{TEAVM_VERSION}",
)

mavenjar(
    name="commons-io",
    artifact="commons-io:commons-io:2.20.0",
)

mavenjar(
    name="jzlib",
    artifact="com.jcraft:jzlib:1.1.3",
)

mavenjar(
    name="joda-time",
    artifact="joda-time:joda-time:2.12.2",
)

mavenjar(
    name="teavm-relocated-libs-asm",
    artifact=f"org.teavm:teavm-relocated-libs-asm:{TEAVM_VERSION}",
)

mavenjar(
    name="teavm-relocated-libs-asm-tree",
    artifact=f"org.teavm:teavm-relocated-libs-asm-tree:{TEAVM_VERSION}",
)

mavenjar(
    name="teavm-relocated-libs-asm-analysis",
    artifact=f"org.teavm:teavm-relocated-libs-asm-analysis:{TEAVM_VERSION}",
)

mavenjar(
    name="teavm-jso",
    artifact=f"org.teavm:teavm-jso:{TEAVM_VERSION}",
)


javalibrary(
    name="main",
    deps=[".+teavm-interop"],
    srcitems={
        "com/cowlark/wordgrinder/Main.java": "./Main.java",
        "com/cowlark/wordgrinder/Display.java": "./Display.java",
        "com/cowlark/wordgrinder/Screen.java": "./Screen.java",
        "com/cowlark/wordgrinder/Clipboard.java": "./Clipboard.java",
    },
)

javaprogram(
    name="wordgrinder",
    mainclass="com.cowlark.wordgrinder.Main",
    deps=[".+main"],
)


# Generate and compile TeaVM C, then link it with the C++ display adapter.
teavm_native = simplerule(
    name="wordgrinder-teavm",
    ins=[".+main", "./display.h", "./clipboard.h"],
    deps=[
        ".+teavm-cli",
        ".+teavm-core",
        ".+teavm-tooling",
        ".+teavm-classlib",
        ".+teavm-relocated-libs-commons-cli",
        ".+teavm-interop",
        ".+teavm-metaprogramming-api",
        ".+teavm-relocated-libs-asm-commons",
        ".+teavm-relocated-libs-asm-util",
        ".+teavm-relocated-libs-hppc",
        ".+teavm-relocated-libs-rhino",
        ".+teavm-relocated-libs-commons-io",
        ".+teavm-platform",
        ".+teavm-jso-apis",
        ".+teavm-jso-impl",
        ".+teavm-metaprogramming-impl",
        ".+commons-io",
        ".+jzlib",
        ".+joda-time",
        ".+teavm-relocated-libs-asm",
        ".+teavm-relocated-libs-asm-tree",
        ".+teavm-relocated-libs-asm-analysis",
        ".+teavm-jso",
    ],
    outs=["=wordgrinder.o"],
    commands=[
        "$(JAVA) -cp '$[\":\".join(filenamesof(deps))]' "
        "org.teavm.cli.TeaVMRunner -t c -d $[dir]/c "
        "-p $[ins[0]] $[deps] -- com.cowlark.wordgrinder.Main",
        "$(CC) $(CFLAGS) "
        "-Ijava/com/cowlark/wordgrinder "
        "-std=c11 -c -o $[outs[0]] $[dir]/c/all.c",
    ],
    label="TEAVM",
    traits={"clibrary"},
)
teavm_native.args["clibrary_deps"] = [teavm_native]
teavm_native.args["clibrary_files"] = [teavm_native]


# C ABI adapters for the existing C++ display backend.
cxxlibrary(
    name="display-native",
    srcs=["./display.cc"],
    hdrs={"display.h": "./display.h"},
    deps=["src/c/arch/ncurses"],
)


cxxlibrary(
    name="clipboard-native",
    srcs=["./clipboard.cc"],
    hdrs={"clipboard.h": "./clipboard.h"},
    deps=["third_party/clip+clip_none"],
)


cxxprogram(
    name="wordgrinder-c",
    srcs=[],
    deps=[".+wordgrinder-teavm", ".+display-native", ".+clipboard-native"],
)
