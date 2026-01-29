plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.ekadashi_calendar"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.ekadashi_calendar"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Desugaring for Java 8+ time APIs
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // ============================================================
    // NATIVE HYBRID ARCHITECTURE DEPENDENCIES (v2.0)
    // ============================================================

    // Location - Native FusedLocationProviderClient (replaces Geolocator plugin)
    implementation("com.google.android.gms:play-services-location:21.0.1")

    // WorkManager - Reliable notification scheduling (replaces AlarmManager)
    implementation("androidx.work:work-runtime-ktx:2.9.0")

    // Coroutines - Async operations on IO threads (prevents main thread blocking)
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.7.3")

    // Splash Screen - Android 12+ API for seamless launch
    implementation("androidx.core:core-splashscreen:1.0.1")
}