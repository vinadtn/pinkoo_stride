allprojects {
    repositories {
        google()
        mavenCentral()

        // Mapbox phát hành SDK qua maven riêng, bắt buộc Basic Auth bằng secret token
        // (scope `Downloads:Read`). Token KHÔNG nằm trong repo — đặt ở
        // `~/.gradle/gradle.properties`:  MAPBOX_DOWNLOADS_TOKEN=sk.xxx
        // hoặc biến môi trường cùng tên (dùng cho CI).
        maven {
            url = uri("https://api.mapbox.com/downloads/v2/releases/maven")
            authentication { create<BasicAuthentication>("basic") }
            credentials {
                // Mapbox quy định username luôn là "mapbox", password là secret token.
                username = "mapbox"
                password = (project.findProperty("MAPBOX_DOWNLOADS_TOKEN") as String?)
                    ?: System.getenv("MAPBOX_DOWNLOADS_TOKEN")
                    ?: ""
            }
            content { includeGroupByRegex("com\\.mapbox.*") }
        }
    }
}

// Android SDK trên máy này cài API 37 vào `platforms/android-37.0`, nhưng Gradle
// đi tìm `android-37` → mọi plugin ghim cứng `compileSdk = 37`
// (permission_handler_android...) đều đổ. Hạ tất cả về 36 — bản có thật trong SDK.
//
// Khối này phải đứng TRƯỚC `evaluationDependsOn(":app")` bên dưới: block đó buộc
// project được evaluate ngay, mà `afterEvaluate` thì không gắn được vào project
// đã evaluate xong.
//
// Bỏ khối này khi SDK có `platforms/android-37`.
subprojects {
    afterEvaluate {
        extensions.findByName("android")?.let { ext ->
            when (ext) {
                is com.android.build.api.dsl.ApplicationExtension -> ext.compileSdk = 36
                is com.android.build.api.dsl.LibraryExtension -> ext.compileSdk = 36
                else -> {}
            }
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
