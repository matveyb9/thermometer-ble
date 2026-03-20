// ─────────────────────────────────────────────────────────────
//  android/settings.gradle.kts
//  Версии AGP и Kotlin объявляются здесь (Plugin DSL, Flutter 3.16+)
//
//  ⚠️  AGP 9 пока НЕ поддерживается Flutter-плагинами — не обновлять!
//      https://docs.flutter.dev/release/breaking-changes/migrate-to-agp-9
//
//  Совместимость (проверено для Flutter 3.41.2):
//    AGP     8.7.3
//    Kotlin  2.1.0
//    Gradle  8.10.2  (android/gradle/wrapper/gradle-wrapper.properties)
//    JDK     17      (встроен в Android Studio Meerkat)
// ─────────────────────────────────────────────────────────────

pluginManagement {
    val flutterSdkPath: String = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val path = properties.getProperty("flutter.sdk")
        checkNotNull(path) { "flutter.sdk не задан в local.properties" }
    }
    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application")          version "8.7.3" apply false
    id("org.jetbrains.kotlin.android")     version "2.1.0" apply false
}

include(":app")
