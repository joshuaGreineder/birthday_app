import java.io.FileInputStream
import java.util.Properties
import org.gradle.api.GradleException

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing follows the Flutter pattern:
// https://docs.flutter.dev/deployment/android#signing-the-app
// android/key.properties is gitignored. Release never falls back to the debug keystore.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

val keystoreStorePath = keystoreProperties.getProperty("storeFile")
val keystoreStore = if (keystoreStorePath.isNullOrBlank()) null else file(keystoreStorePath)
val missingSigningKeys = listOf("storePassword", "keyPassword", "keyAlias", "storeFile")
    .filter { keystoreProperties.getProperty(it).isNullOrBlank() }

val releaseSigningProblem: String? = when {
    !keystorePropertiesFile.exists() ->
        "Release builds require android/key.properties with storePassword, keyPassword, keyAlias, and storeFile. " +
            "Happaroo does not sign release builds with the debug keystore. " +
            "See https://docs.flutter.dev/deployment/android#signing-the-app"
    missingSigningKeys.isNotEmpty() ->
        "android/key.properties is missing ${missingSigningKeys.joinToString(", ")}. " +
            "Release builds do not fall back to the debug keystore."
    keystoreStore == null || !keystoreStore.exists() ->
        "Upload keystore was not found at the storeFile path in android/key.properties. " +
            "Release builds do not fall back to the debug keystore."
    else -> null
}

val releaseSigningReady = releaseSigningProblem == null

android {
    namespace = "com.greinederlabs.happaroo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Enable core library desugaring (required for flutter_local_notifications)
        isCoreLibraryDesugaringEnabled = true

        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.greinederlabs.happaroo"
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        // Play requires target API 36 for new apps and updates (31 Aug 2026; the
        // 1 Nov 2026 extension has passed). The Flutter revision in .metadata
        // (f6ff1529fd6d8af5f706051d9251ac9231c83407) defaults targetSdkVersion to 36,
        // so this stays on flutter.targetSdkVersion instead of pinning a second value.
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseSigningReady) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storePassword = keystoreProperties.getProperty("storePassword")
                storeFile = keystoreStore!!
            }
        }
    }

    buildTypes {
        release {
            if (releaseSigningReady) {
                signingConfig = signingConfigs.getByName("release")
            }
            // Gson rules for flutter_local_notifications. The notification icon is kept by res/raw/keep.xml.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    applicationVariants.all {
        outputs.all {
            val output = this as com.android.build.gradle.internal.api.BaseVariantOutputImpl
            val apkName = "Happaroo-v${versionName}-${versionCode}.apk"
            output.outputFileName = apkName
        }
    }
}

tasks.configureEach {
    if (name.contains("Release") && !name.contains("AndroidTest")) {
        doFirst {
            val error = releaseSigningProblem
            if (error != null) {
                throw GradleException(error)
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Core library desugaring (required for flutter_local_notifications)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.2")
}
