// Upstream asks for a Java 17 toolchain in libraries/common, jdb and config.
// Without a local JDK 17, Gradle 9 asks foojay 0.8.0 to download one and foojay
// crashes (JvmVendorSpec.IBM_SEMERU no longer exists). Compile those modules with
// JDK 21 instead; their `options.release = 17` still pins the bytecode to Java 17.
allprojects {
    afterEvaluate {
        extensions.findByType<JavaPluginExtension>()?.toolchain?.languageVersion
            ?.set(JavaLanguageVersion.of(21))
    }
}
