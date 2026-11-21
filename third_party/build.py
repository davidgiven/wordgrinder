from build.java import mavenjar

# Use a common version for all TeaVM modules.
TEAVM_VERSION = "0.16.0"

# List the Maven coordinates to download.
MAVEN_ARTIFACTS = [
    # Nullness annotations.
    "org.jspecify:jspecify:1.0.0",

    # Guava's Android variant and its supporting runtime and annotation libraries.
    "com.google.guava:guava:33.8.0-android",
    "com.google.guava:failureaccess:1.0.3",
    "com.google.errorprone:error_prone_annotations:2.52.0",
    "com.google.j2objc:j2objc-annotations:3.1",

    # TeaVM compiler modules and their dependencies.
    f"org.teavm:cli:{TEAVM_VERSION}",
    f"org.teavm:teavm-tooling:{TEAVM_VERSION}",
    f"org.teavm:teavm-core:{TEAVM_VERSION}",
    f"org.teavm:teavm-classlib:{TEAVM_VERSION}",
    f"org.teavm:teavm-platform:{TEAVM_VERSION}",
    f"org.teavm:teavm-interop:{TEAVM_VERSION}",
    "commons-cli:commons-cli:1.11.0",
    f"org.teavm:teavm-metaprogramming-api:{TEAVM_VERSION}",
    f"org.teavm:teavm-relocated-libs-asm-commons:{TEAVM_VERSION}",
    f"org.teavm:teavm-relocated-libs-asm-util:{TEAVM_VERSION}",
    f"org.teavm:teavm-relocated-libs-hppc:{TEAVM_VERSION}",
    f"org.teavm:teavm-relocated-libs-rhino:{TEAVM_VERSION}",
    f"org.teavm:teavm-jso-apis:{TEAVM_VERSION}",
    f"org.teavm:teavm-jso-impl:{TEAVM_VERSION}",
    f"org.teavm:teavm-metaprogramming-impl:{TEAVM_VERSION}",
    "com.jcraft:jzlib:1.1.3",
    "joda-time:joda-time:2.12.2",
    f"org.teavm:teavm-relocated-libs-asm:{TEAVM_VERSION}",
    f"org.teavm:teavm-relocated-libs-asm-tree:{TEAVM_VERSION}",
    f"org.teavm:teavm-relocated-libs-asm-analysis:{TEAVM_VERSION}",
    f"org.teavm:teavm-jso:{TEAVM_VERSION}",

    # Additional compiler/runtime modules introduced since TeaVM 0.14.
    f"org.teavm:teavm-c-incremental:{TEAVM_VERSION}",
    f"org.teavm:teavm-extension-apis:{TEAVM_VERSION}",
    f"org.teavm:teavm-extension-spi:{TEAVM_VERSION}",
    f"org.teavm:teavm-extension-spi-util:{TEAVM_VERSION}",

    # Runtime dependencies from the TeaVM 0.16.0 Maven POMs.
    "org.ow2.asm:asm:9.10.1",
    "org.ow2.asm:asm-tree:9.10.1",
    "org.ow2.asm:asm-analysis:9.10.1",
    "org.ow2.asm:asm-commons:9.10.1",
    "org.ow2.asm:asm-util:9.10.1",
    "org.mozilla:rhino:1.9.1",
    "com.carrotsearch:hppc:0.10.0",
]

# Derive rule names from the group and artifact IDs, excluding the version.
RULE_NAME_TRANSLATION = str.maketrans(".-:", "___")
MAVEN_RULES = {
    ":".join(artifact.split(":", 2)[:2]).translate(RULE_NAME_TRANSLATION): artifact
    for artifact in MAVEN_ARTIFACTS
}

# Register a download rule for each Maven artifact.
for name, artifact in MAVEN_RULES.items():
    mavenjar(name=name, artifact=artifact)
