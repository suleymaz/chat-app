import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Imza bilgileri depoya gonderilmeyen key.properties dosyasindan okunuyor.
// Ornegi key.properties.example dosyasinda.
val anahtarDosyasi = rootProject.file("key.properties")
val anahtarlar = Properties().apply {
    if (anahtarDosyasi.exists()) {
        FileInputStream(anahtarDosyasi).use { load(it) }
    }
}
val imzaVar = anahtarDosyasi.exists()

android {
    namespace = "com.suleyman.chat_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.suleyman.chat_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (imzaVar) {
                keyAlias = anahtarlar.getProperty("keyAlias")
                keyPassword = anahtarlar.getProperty("keyPassword")
                storeFile = file(anahtarlar.getProperty("storeFile"))
                storePassword = anahtarlar.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // key.properties yoksa debug anahtarina duselim: projeyi klonlayan
            // biri, imza anahtari olmadan da release derlemesi alabilsin.
            signingConfig = if (imzaVar) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
