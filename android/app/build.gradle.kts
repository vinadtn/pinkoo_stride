import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Khoá ký bản release. `android/key.properties` và file keystore KHÔNG vào git —
// mất chúng là không cập nhật được app đã cài (phải cài lại, mất dữ liệu local),
// nên nhớ sao lưu cả hai.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { load(it) }
    }
}
val hasReleaseKey = keystoreProperties.containsKey("storeFile")

android {
    namespace = "com.wenemrtad.pinkoo.stride"
    compileSdk = 36 // SDK máy chưa có platforms/android-37 (xem android/build.gradle.kts)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.wenemrtad.pinkoo.stride"
        minSdk = 24 // Mapbox Maps v11 + foreground service location
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Không có key.properties (máy khác, hoặc CI chưa cấu hình) thì vẫn
            // build được bằng debug key — để `flutter run --release` không đứng.
            signingConfig = signingConfigs.getByName(if (hasReleaseKey) "release" else "debug")
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
    // FileProvider — cấp quyền đọc file ảnh/gpx tạm cho app nhận share
    // (StorySharePlugin.kt). Flutter kéo androidx.core theo đường gián tiếp,
    // nhưng khai rõ ở đây để không phụ thuộc vào thứ tự giải phụ thuộc.
    implementation("androidx.core:core-ktx:1.17.0")
}
