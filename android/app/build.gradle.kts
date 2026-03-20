// ─────────────────────────────────────────────────────────────
//  android/app/build.gradle.kts
// ─────────────────────────────────────────────────────────────

import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // Flutter Gradle Plugin — применять строго ПОСЛЕ Android и Kotlin
    id("dev.flutter.flutter-gradle-plugin")
}

// ── Подпись релизной сборки ───────────────────────────────────
// Данные берутся из android/key.properties (файл в .gitignore).
// На CI (Codemagic) файл создаётся скриптом из секретов.
val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties().apply {
    if (keyPropertiesFile.exists()) {
        keyPropertiesFile.inputStream().use { load(it) }
    }
}

android {
    namespace  = "ru.matveyb9.diy.thermometer"
    compileSdk = flutter.compileSdkVersion   // управляется Flutter SDK (35)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    signingConfigs {
        create("release") {
            // Если key.properties не найден (локальная сборка без подписи)
            // — Gradle просто пропустит подпись и соберёт unsigned APK.
            if (keyPropertiesFile.exists()) {
                storeFile     = file(keyProperties["storeFile"] as String)
                storePassword = keyProperties["storePassword"] as String
                keyAlias      = keyProperties["keyAlias"] as String
                keyPassword   = keyProperties["keyPassword"] as String
                storeType     = "PKCS12"  // формат хранилища ключей
            }
        }
    }

    defaultConfig {
        applicationId = "ru.matveyb9.diy.thermometer"

        // BLE требует минимум API 21 (Android 5.0 Lollipop)
        // flutter_blue_plus также требует minSdk >= 21
        minSdk    = 21
        targetSdk = flutter.targetSdkVersion  // управляется Flutter SDK (35)

        // versionCode и versionName берутся из pubspec.yaml (version: 1.0.0+1)
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = if (keyPropertiesFile.exists())
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")  // fallback для unsigned сборки

            // Минификация кода (ProGuard / R8)
            isMinifyEnabled = false
        }
        debug {
            isDebuggable = true
        }
    }
}

flutter {
    source = "../.."
}
