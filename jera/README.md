# JeraCraft FancyNpcs fork (Java 21)

FancyNpcs for JeraCraft's Folia 1.21.11 servers, which run Java 21. Upstream's
Java 21 build (`2.10.1-java21+2`) has two bugs fixed only in later Java 25 builds:

- `Npc.update()` throws `NullPointerException` when the FancyNpcsModel plugin is not
  installed, so name, glow and equipment changes don't render until a restart.
- `CamelAttributes` calls `Bukkit.getScheduler()`, which throws on Folia.

Branch `jera/java21-patches` = upstream `java-21` @ `512aa29d` plus cherry-picks
`c7435c57` (custom_model null guard) and `47cad779` (camel pose on the global region
scheduler, `_` lambda rewritten as `task` for Java 21). Version `2.10.1-java21+2-jera.1`.

## Build (JDK 21)

    $env:JAVA_HOME = 'C:\Program Files\Eclipse Adoptium\jdk-21.0.11.10-hotspot'
    .\gradlew.bat -I jera\jdk21-only.init.gradle.kts :plugins:fancynpcs-v2:shadowJar

Output: `plugins/fancynpcs-v2/build/libs/FancyNpcs-2.10.1-java21+2-jera.1.jar`.
The init script compiles upstream's Java 17 modules with JDK 21 (bytecode stays 17),
because Gradle 9 + foojay 0.8.0 crash when asked to download a JDK 17.

## Verify

    powershell -File jera\verify-jar.ps1 -Jar <jar>

Checks A (all classes Java 21), B (custom_model guard), C (no `getScheduler` in camel).
Stock `2.10.1-java21+2` fails B and C; this fork passes all three.

Retire this fork once prod runs Java 25 (use stock FancyNpcs) or upstream ships a
Java 21 build with both fixes.
