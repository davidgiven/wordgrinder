from config import VERSION
from shlex import quote
from build.ab import simplerule
from build.c import clibrary, cxxprogram
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
             "./nativeinterface/teavm",
             "./eventbus",
             "./document",
             "./fileio",
             "./ui",
             "./ui+menu-settings",
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

# Generate self-contained TeaVM C shards for the compiler sandboxes.
TEAVM_SHARDS = [f"=wordgrinder-{index:02x}.c" for index in range(32)]
teavm_native = simplerule(
    name="wordgrinder-teavm",
    ins=[".+main"],
    deps=GUAVA_DEPS
         + [
             "./teavm",
             "./teavm+driver",
             "./nativeinterface",
             "./nativeinterface/teavm",
             "./ui",
             "./app",
             "./utils",
             "./addons/debug+settings",
             "./addons/directories+settings",
             "./addons/gui+settings",
             "./addons/lookandfeel+settings",
             "./addons/recents+settings",
             "./addons/spillchocker+settings",
             "./addons/undo",
             "./eventbus",
             "./document",
             "./fileio",
             "third_party+org_jspecify_jspecify",
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
    outs=TEAVM_SHARDS,
    commands=[
        "$(JAVA) -cp '$[\":\".join(filenamesof(ins[:1] + deps))]' "
        "com.cowlark.wordgrinder.teavm.TeaVMCDriver com.cowlark.wordgrinder.Main $[outs]",
    ],
    label="TEAVM",
)


# Compile each shard independently and link the archive with the native adapters.
clibrary(
    name="wordgrinder-teavm-c",
    srcs=[teavm_native],
    deps=["./nativeinterface/teavm+native"],
    cflags=["-std=c11", "-fno-unwind-tables", "-fno-asynchronous-unwind-tables"],
)

cxxprogram(
    name="wordgrinder-c",
    srcs=[],
    deps=[".+wordgrinder-teavm-c"],
)
