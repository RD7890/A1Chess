import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// ABI → versionCode suffix mapping.
// arm64-v8a (suffix 2) → Redmi 12C and other 64-bit devices
// armeabi-v7a (suffix 1) → Poco C3 and older 32-bit devices
val abiVersionCodes = mapOf("armeabi-v7a" to 1, "arm64-v8a" to 2)

android {
    namespace = "com.ryzix.rdchess"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        multiDexEnabled = true
        applicationId = "com.ryzix.rdchess"
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["appAuthRedirectScheme"] = "com.ryzix.rdchess"

        // Strip unused locale resources from Android framework and third-party libs.
        resourceConfigurations += listOf("en")
    }

    // Produce one lean APK per ABI instead of one fat APK with all native libs.
    // Result: app-arm64-v8a-release.apk (Redmi 12C) + app-armeabi-v7a-release.apk (Poco C3)
    splits {
        abi {
            isEnable = true
            reset()
            include("arm64-v8a", "armeabi-v7a")
            isUniversalApk = false
        }
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.getByName("release")
        }
        debug {
            applicationIdSuffix = ".debug"
        }
    }

    // Compress native libs (.so) in the APK — reduces download size significantly.
    // Android extracts them at install time. Without this, Stockfish's libstockfish.so
    // alone inflates the APK to 150-200 MB uncompressed.
    packagingOptions {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    dependenciesInfo {
        includeInApk = false
        includeInBundle = true
    }
}

// Rename each split APK to a human-readable filename and assign a unique
// versionCode per ABI (required if uploading multiple APKs to Play Store).
android.applicationVariants.all {
    val variant = this
    variant.outputs
        .map { it as com.android.build.gradle.internal.api.BaseVariantOutputImpl }
        .forEach { output ->
            val abiName = output.getFilter(com.android.build.OutputFile.ABI)
            val abiCode = abiVersionCodes.getOrDefault(abiName, 0)
            if (abiCode != 0) {
                output.versionCodeOverride = variant.versionCode * 10 + abiCode
            }
            output.outputFileName = if (abiName != null) {
                "rdchess-${variant.versionName}-${abiName}.apk"
            } else {
                "rdchess-${variant.versionName}-universal.apk"
            }
        }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.core:core-splashscreen:1.0.1")
}
