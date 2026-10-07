// GiftCard Pro – POS integration module (reference implementation for Android till apps).
// The sources in src/main/kotlin are plain Kotlin (no Android dependency) and are copied into the till app as they
// are; android/IsoDepCardChannel.kt is the 15-line Android adapter. This build only compiles and tests them on the JVM.
plugins {
    kotlin("jvm") version "2.2.20"
}

repositories {
    mavenCentral()
}

dependencies {
    // Part of Android itself; on the JVM only for the tests.
    compileOnly("org.json:json:20180813")
    testImplementation("org.json:json:20180813")
    testImplementation("junit:junit:4.12")
    testImplementation(kotlin("test-junit"))
}

