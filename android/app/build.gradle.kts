import org.gradle.api.tasks.Copy 

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("com.chaquo.python")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.curio.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "29.0.14206865"

    defaultConfig {
        applicationId = "com.curio.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // ✅ REQUIRED FOR CHAQUOPY AND FFMPEG
        ndk {
            abiFilters += listOf(
                "arm64-v8a",
                "x86_64"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlin {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
            pickFirsts.add("**/libc++_shared.so")
            doNotStrip.add("**/libpython.zip.so")
            doNotStrip.add("**/*.zip.so")
            doNotStrip.add("**/*.so")
        }
    }
}

flutter {
    source = "../.."
}
chaquopy {
    defaultConfig {
        buildPython = listOf("C:/Python311/python.exe")
pyc {
            src = false
        }
        // Runtime Python bundled into the APK.
        version = "3.11" 

        pip {
            options("--pre")
            install("yt-dlp[default]")
            install("yt-dlp-ejs")
            install("mutagen")
            install("pycryptodomex")
        }
    }
}




dependencies {
    // Keep Kotlin stdlib aligned with the Kotlin Gradle plugin to avoid metadata mismatch.
    implementation(platform("org.jetbrains.kotlin:kotlin-bom:2.2.0"))
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    
    // Gson for JSON conversion
    implementation("com.google.code.gson:gson:2.10.1")
}
// ----------  APK-copy task (Kotlin-DSL)  ----------
tasks.register<Copy>("copyReleaseApk") {
    from(file("$buildDir/outputs/flutter-apk/app-release.apk"))
    into(file("$rootDir/../build/app/outputs/flutter-apk"))
}

// ----------  hook it to assembleRelease  ----------
afterEvaluate {
    tasks.named("assembleRelease") {
        finalizedBy("copyReleaseApk")
    }
}

tasks.register<Copy>("copyDebugApk") {
    from(file("$buildDir/outputs/flutter-apk/app-debug.apk"))
    into(file("$rootDir/../build/app/outputs/flutter-apk"))
}

afterEvaluate {
    tasks.named("assembleDebug") { finalizedBy("copyDebugApk") }
}

