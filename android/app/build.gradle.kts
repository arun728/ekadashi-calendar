import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

val glassPreview = providers.gradleProperty("glassPreview").orNull == "true"

android {
    namespace = "com.applausestudios.ekadashi_calendar"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    testOptions {
        unitTests.isIncludeAndroidResources = true
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            val storeFileName = keystoreProperties.getProperty("storeFile")
            if (storeFileName != null) {
                storeFile = file(storeFileName)
            }
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = if (glassPreview)
            "com.applausestudios.ekadashi_calendar.glasspreview"
        else "com.applausestudios.ekadashi_calendar"
        manifestPlaceholders["appLabel"] = if (glassPreview)
            "Ekadashi Glass Preview" else "Ekadashi Calendar"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            // R8 configuration
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")

        }
    }

}

kotlin {
    compilerOptions {
        jvmTarget = JvmTarget.fromTarget(JavaVersion.VERSION_17.toString())
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Match the runner used by instrumentation with the debug runtime (Flutter
    // integration_test otherwise selects runner 1.2.0 by consistent resolution).
    debugImplementation("androidx.test:runner:1.6.2")
    androidTestImplementation("androidx.test:runner:1.6.2")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("androidx.test.uiautomator:uiautomator:2.3.0")
    // integration_test supplies Guava at runtime, which selects the empty
    // listenablefuture artifact. Expose that existing API to Kotlin compilation
    // without adding or changing a runtime dependency.
    compileOnly("com.google.guava:guava:28.1-android")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.robolectric:robolectric:4.14.1")
    testImplementation("androidx.test:core:1.6.1")
    testImplementation("androidx.work:work-testing:2.9.0")
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
