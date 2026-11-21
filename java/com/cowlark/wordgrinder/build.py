from config import VERSION
from shlex import quote
from build.ab import simplerule
from build.c import cxxprogram
from build.java import javalibrary, javaprogram

GUAVA_DEPS = [
    "third_party+com_google_guava_guava",
    "third_party+com_google_guava_failureaccess",
    "third_party+com_google_errorprone_error_prone_annotations",
    "third_party+com_google_j2objc_j2objc_annotations",
]

# Expose the shared application version to Java command-line help.
simplerule(
    name="build-info-source",
    outs=["=BuildInfo.java"],
    commands=[
        "printf '%s' "
        + quote(
            "package com.cowlark.wordgrinder;\n"
            "/* Application version supplied by the shared build configuration. */\n"
            "final class BuildInfo {\n"
            f'    static final String VERSION = "{VERSION}";\n'
            "    /* TODO: Supply a debug flag when Java debug builds are supported. */\n"
            "    static final boolean DEBUG = false;\n"
            "}\n"
        )
        + " > $[outs[0]]",
    ],
    label="BUILDINFO",
)

javalibrary(
    name="build-info",
    srcitems={
        f"com/cowlark/wordgrinder/{f}": ".+build-info-source"
        for f in ["BuildInfo.java"]
    },
)

javalibrary(
    name="main",
    deps=GUAVA_DEPS
    + [
        ".+build-info",
        "./nativeinterface",
        "./teavm/impl",
        "./eventbus",
        "./document",
        "./fileio",
        "./ui",
        "./app",
        "./utils",
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
    ins=[
        ".+main",
        "./teavm/impl/display.h",
        "./teavm/impl/clipboard.h",
        "./teavm/impl/system.h",
    ],
    deps=GUAVA_DEPS
    + [
        "./teavm",
        "./nativeinterface",
        "./teavm/impl",
        "./ui",
        "./app",
        "./utils",
        "./addons/debug+settings",
        "./addons/directories+settings",
        "./addons/gui+settings",
        "./addons/lookandfeel+settings",
        "./addons/recents+settings",
        "./addons/spillchocker+settings",
        "./eventbus",
        "./document",
        "./fileio",
        "third_party+org_jspecify_jspecify",
        "third_party+org_teavm_cli",
        "third_party+org_teavm_teavm_c_incremental",
        "third_party+org_teavm_teavm_extension_apis",
        "third_party+org_teavm_teavm_extension_spi",
        "third_party+org_teavm_teavm_extension_spi_util",
        "third_party+org_ow2_asm_asm",
        "third_party+org_ow2_asm_asm_tree",
        "third_party+org_ow2_asm_asm_analysis",
        "third_party+org_ow2_asm_asm_commons",
        "third_party+org_ow2_asm_asm_util",
        "third_party+org_mozilla_rhino",
        "third_party+com_carrotsearch_hppc",
        "third_party+org_teavm_teavm_core",
        "third_party+org_teavm_teavm_tooling",
        "third_party+org_teavm_teavm_classlib",
        "third_party+commons_cli_commons_cli",
        "third_party+org_teavm_teavm_interop",
        "third_party+org_teavm_teavm_metaprogramming_api",
        "third_party+org_teavm_teavm_relocated_libs_asm_commons",
        "third_party+org_teavm_teavm_relocated_libs_asm_util",
        "third_party+org_teavm_teavm_relocated_libs_hppc",
        "third_party+org_teavm_teavm_relocated_libs_rhino",
        "third_party+org_teavm_teavm_platform",
        "third_party+org_teavm_teavm_jso_apis",
        "third_party+org_teavm_teavm_jso_impl",
        "third_party+org_teavm_teavm_metaprogramming_impl",
        "third_party+com_jcraft_jzlib",
        "third_party+joda_time_joda_time",
        "third_party+org_teavm_teavm_relocated_libs_asm",
        "third_party+org_teavm_teavm_relocated_libs_asm_tree",
        "third_party+org_teavm_teavm_relocated_libs_asm_analysis",
        "third_party+org_teavm_teavm_jso",
    ],
    outs=["=wordgrinder.o"],
    commands=[
        "$(JAVA) -cp '$[\":\".join(filenamesof(deps))]' "
        "org.teavm.cli.TeaVMRunner -t c -d $[dir]/c "
        "-p $[ins[0]] $[deps] -- com.cowlark.wordgrinder.Main",
        "$(CC) $(CFLAGS) "
        "-Ijava/com/cowlark/wordgrinder/teavm/impl "
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
    deps=[".+wordgrinder-teavm", "./teavm/impl+native"],
)
