import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing (upload key). android/key.properties is not committed:
//   storeFile=/absolute/or/android-relative/path/upload-keystore.jks
//   storePassword=…
//   keyAlias=upload
//   keyPassword=…
// Without it, release builds are signed with the DEBUG key so that
// `flutter run --release` works locally. Such an APK/AAB cannot be uploaded
// to Play and its signature does not match assetlinks.json (App Links will not
// verify). A warning is logged whenever this fallback is used.
val keystoreProperties = Properties()
val keystorePropertiesFile: File = rootProject.file("key.properties")
val hasReleaseKeystore: Boolean = keystorePropertiesFile.isFile
if (hasReleaseKeystore) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

// Flutter passes all --dart-define values (also those of --dart-define-from-file)
// as the Gradle property `dart-defines`: a comma-separated list of
// base64-encoded `KEY=VALUE` entries.
val dartDefines: Map<String, String> = (project.findProperty("dart-defines")?.toString().orEmpty())
    .split(',')
    .filter { it.isNotBlank() }
    .mapNotNull { entry ->
        val decoded = try {
            String(Base64.getDecoder().decode(entry.trim()), Charsets.UTF_8)
        } catch (_: IllegalArgumentException) {
            return@mapNotNull null
        }
        val separator = decoded.indexOf('=')
        if (separator <= 0) null else decoded.substring(0, separator) to decoded.substring(separator + 1)
    }
    .toMap()

// APP_ENV (config/<environment>.json): development and staging builds get their
// own application id and launcher name, so they install next to the store app,
// and development builds may use plain http to a server on the local network.
// Missing APP_ENV = production (strictest).
val appEnv: String = dartDefines["APP_ENV"]?.trim()?.lowercase()?.ifEmpty { null } ?: "production"
val appEnvSuffix: String = when (appEnv) {
    "development", "dev" -> ".dev"
    "staging" -> ".staging"
    else -> ""
}
val appLabel: String = when (appEnv) {
    "development", "dev" -> "GiftCard Waiter Dev"
    "staging" -> "GiftCard Waiter Staging"
    else -> "GiftCard Waiter"
}
val networkSecurityConfig: String =
    if (appEnvSuffix == ".dev") "network_security_config_development" else "network_security_config"

// The first host of the CARD_DOMAINS dart-define becomes the host of the NFC
// NDEF and App Links intent filters (09 §7.1, §7.4). Without CARD_DOMAINS the
// filters use "localhost" (they then match no real card).
fun cardHostFromDartDefines(): String =
    dartDefines["CARD_DOMAINS"]
        ?.split(',')
        ?.map { it.trim().lowercase() }
        ?.firstOrNull { it.isNotEmpty() }
        ?: "localhost"

android {
    namespace = "eu.tapredeem.waiter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Neutral identifier without the product name (13 Q10).
        applicationId = "eu.tapredeem.waiter"
        // Android 9 is the oldest OS in the test matrix (09 §11.3).
        minSdk = 28
        // Google Play: new apps and updates must target API 36 since 31 Aug 2026. Pinned so an SDK
        // update cannot silently change it.
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        applicationIdSuffix = appEnvSuffix
        manifestPlaceholders["cardHost"] = cardHostFromDartDefines()
        manifestPlaceholders["appLabel"] = appLabel
        manifestPlaceholders["networkSecurityConfig"] = networkSecurityConfig
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (hasReleaseKeystore) "release" else "debug")
            isMinifyEnabled = true
            isShrinkResources = true
            // Flutter's own keep rules are added by the Flutter Gradle plugin;
            // plugins ship theirs as consumer rules.
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"))
        }
    }
}

if (!hasReleaseKeystore) {
    gradle.taskGraph.whenReady {
        if (allTasks.any { it.path.startsWith(":app:") && it.name.contains("Release") }) {
            logger.warn(
                "WARNING: android/key.properties not found — the release build is signed with the DEBUG key. " +
                    "Do not distribute it: Play rejects it and App Links (assetlinks.json) will not verify.",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
