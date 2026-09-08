import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val hasReleaseKeystore = rootProject.file("key.properties").exists()

android {
    namespace = "com.pomosauce.app"

    // Play requires new apps and updates to target Android 16 (API 36) from
    // September 2026. compileSdk is pinned to the same level so the manifest
    // attributes used above (specialUse FGS subtype, exact-alarm APIs) all
    // resolve. Re-check the current threshold in Play Console before release.
    compileSdk = 36

    // NDK r27+ produces 16 KB page-aligned shared libraries, which Play
    // requires for apps shipping native code. Verify a release build with
    // `tool/check_16kb_alignment.sh` before uploading.
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.pomosauce.app"
        // flutter_local_notifications and flutter_foreground_task both need 21+;
        // 24 keeps the notification-channel code paths simple.
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Release signing is read from android/key.properties, which is git
        // ignored. See README > Release build. Falls back to debug signing so
        // `flutter build apk --release` works on a fresh clone.
        create("release") {
            val props = Properties()
            val propsFile = rootProject.file("key.properties")
            if (propsFile.exists()) {
                propsFile.inputStream().use { props.load(it) }
                keyAlias = props.getProperty("keyAlias")
                keyPassword = props.getProperty("keyPassword")
                storeFile = props.getProperty("storeFile")?.let { file(it) }
                storePassword = props.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                // Local convenience only. bundleRelease refuses to produce a
                // debug-signed AAB - see the guard below.
                logger.warn(
                    "*** android/key.properties is missing - this release " +
                        "build is DEBUG SIGNED and cannot be uploaded to " +
                        "Play. See android/key.properties.example. ***"
                )
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    packaging {
        jniLibs {
            // Uncompressed, page-aligned native libraries: required for the
            // 16 KB page size rollout and smaller on disk at install time.
            useLegacyPackaging = false
        }
    }

    bundle {
        // Keep every alarm tone in the base APK. Splitting them by density or
        // language would be wrong, and a missing tone means a silent alarm.
        language { enableSplit = false }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // flutter_local_notifications needs java.time on API < 26.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

// The AAB is the Play upload artifact, so it is the one that must never be
// debug-signed. A debug-signed bundle is rejected on upload anyway - failing
// here turns a confusing Play Console error into an obvious local one.
// Escape hatch for a throwaway test bundle:
//   flutter build appbundle --release \n//     --android-project-arg=allowDebugSigning=true
tasks.matching { it.name == "bundleRelease" }.configureEach {
    doFirst {
        val allowed = project.findProperty("allowDebugSigning") == "true"
        if (!hasReleaseKeystore && !allowed) {
            throw GradleException(
                "Refusing to build a debug-signed release bundle. " +
                    "Google Play will reject it. Create a keystore and " +
                    "android/key.properties (see key.properties.example), or " +
                    "pass --android-project-arg=allowDebugSigning=true to " +
                    "flutter build for a throwaway one."
            )
        }
    }
}

flutter {
    source = "../.."
}
