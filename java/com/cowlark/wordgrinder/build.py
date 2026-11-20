from build.ab import simplerule
from build.c import cxxprogram
from build.java import javalibrary, javaprogram, mavenjar

TEAVM_VERSION = "0.16.0"

mavenjar(name="jspecify", artifact="org.jspecify:jspecify:1.0.0")

# Guava's Android variant and its supporting runtime and annotation libraries.
mavenjar(name="guava", artifact="com.google.guava:guava:33.8.0-android")
mavenjar(name="guava-failureaccess", artifact="com.google.guava:failureaccess:1.0.3")
mavenjar(
    name="guava-error-prone-annotations",
    artifact="com.google.errorprone:error_prone_annotations:2.52.0",
)
mavenjar(name="guava-j2objc-annotations", artifact="com.google.j2objc:j2objc-annotations:3.1")

GUAVA_DEPS = [
    "java/com/cowlark/wordgrinder+guava",
    "java/com/cowlark/wordgrinder+guava-failureaccess",
    "java/com/cowlark/wordgrinder+guava-error-prone-annotations",
    "java/com/cowlark/wordgrinder+guava-j2objc-annotations",
]

mavenjar(name="teavm-cli", artifact=f"org.teavm:cli:{TEAVM_VERSION}")
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

mavenjar(name="commons-cli", artifact="commons-cli:commons-cli:1.11.0")

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

# Additional compiler/runtime modules introduced since TeaVM 0.14.
mavenjar(
    name="teavm-c-incremental", artifact=f"org.teavm:teavm-c-incremental:{TEAVM_VERSION}"
)
mavenjar(
    name="teavm-extension-apis", artifact=f"org.teavm:teavm-extension-apis:{TEAVM_VERSION}"
)
mavenjar(
    name="teavm-extension-spi", artifact=f"org.teavm:teavm-extension-spi:{TEAVM_VERSION}"
)
mavenjar(
    name="teavm-extension-spi-util", artifact=f"org.teavm:teavm-extension-spi-util:{TEAVM_VERSION}"
)

# Runtime dependencies from the TeaVM 0.16.0 Maven POMs.
mavenjar(name="asm", artifact="org.ow2.asm:asm:9.10.1")
mavenjar(name="asm-tree", artifact="org.ow2.asm:asm-tree:9.10.1")
mavenjar(name="asm-analysis", artifact="org.ow2.asm:asm-analysis:9.10.1")
mavenjar(name="asm-commons", artifact="org.ow2.asm:asm-commons:9.10.1")
mavenjar(name="asm-util", artifact="org.ow2.asm:asm-util:9.10.1")
mavenjar(name="rhino", artifact="org.mozilla:rhino:1.9.1")
mavenjar(name="hppc", artifact="com.carrotsearch:hppc:0.10.0")

javalibrary(
    name="main",
    deps=GUAVA_DEPS + [
        "./nativeinterface",
        "./eventbus",
        "./document",
        "./fileio",
        "./forms",
        "./addons/debug+settings",
        "./addons/directories+settings",
        "./addons/gui+settings",
        "./addons/lookandfeel+settings",
        "./addons/recents+settings",
        "./addons/spillchocker+settings",
    ],
    srcitems={
        f"com/cowlark/wordgrinder/{f}": f"./{f}"
        for f in [
            "Context.java",
            "Main.java",
            "Paragraph.java",
            "Word.java",
        ]
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
    ins=[".+main", "./nativeinterface/display.h", "./nativeinterface/clipboard.h"],
    deps=GUAVA_DEPS + [
        "./teavm",
        "./nativeinterface",
        "./forms",
        "./addons/debug+settings",
        "./addons/directories+settings",
        "./addons/gui+settings",
        "./addons/lookandfeel+settings",
        "./addons/recents+settings",
        "./addons/spillchocker+settings",
        "./eventbus",
        "./document",
        "./fileio",
        ".+jspecify",
        ".+teavm-cli",
        ".+teavm-c-incremental",
        ".+teavm-extension-apis",
        ".+teavm-extension-spi",
        ".+teavm-extension-spi-util",
        ".+asm",
        ".+asm-tree",
        ".+asm-analysis",
        ".+asm-commons",
        ".+asm-util",
        ".+rhino",
        ".+hppc",
        ".+teavm-core",
        ".+teavm-tooling",
        ".+teavm-classlib",
        ".+commons-cli",
        ".+teavm-interop",
        ".+teavm-metaprogramming-api",
        ".+teavm-relocated-libs-asm-commons",
        ".+teavm-relocated-libs-asm-util",
        ".+teavm-relocated-libs-hppc",
        ".+teavm-relocated-libs-rhino",
        ".+teavm-platform",
        ".+teavm-jso-apis",
        ".+teavm-jso-impl",
        ".+teavm-metaprogramming-impl",
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
        "-Ijava/com/cowlark/wordgrinder/nativeinterface "
        "-std=c11 -c -o $[outs[0]] $[dir]/c/all.c",
    ],
    label="TEAVM",
    traits={"clibrary"},
)
teavm_native.args["clibrary_deps"] = [teavm_native]
teavm_native.args["clibrary_files"] = [teavm_native]

cxxprogram(
    name="wordgrinder-c",
    srcs=[],
    deps=[".+wordgrinder-teavm", "./nativeinterface+native"],
)
