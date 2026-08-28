plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.intellieffect.drop.mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // 네이티브 시절부터 이어 온 패키지명 — Firebase·Play·Google OAuth(SHA-1) 레코드와 묶여 있다.
        applicationId = "com.intellieffect.drop.mobile"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // 릴리스 서명 (BRU-161). CI(release.yml)가 keystore 시크릿을 풀어 환경변수로 넘긴다.
    // 환경변수가 없으면(로컬 개발) debug 키로 폴백한다 — 단, 그 빌드는 Google 로그인이
    // 안 된다 (등록된 SHA-1과 지문이 다름). CI는 별도 스텝에서 지문을 대조해 끊는다.
    val releaseKeystoreFile = System.getenv("ANDROID_KEYSTORE_FILE")

    signingConfigs {
        if (releaseKeystoreFile != null) {
            create("release") {
                storeFile = file(releaseKeystoreFile)
                storePassword = System.getenv("ANDROID_STORE_PASSWORD")
                keyAlias = System.getenv("ANDROID_KEY_ALIAS")
                keyPassword = System.getenv("ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (releaseKeystoreFile != null) {
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
