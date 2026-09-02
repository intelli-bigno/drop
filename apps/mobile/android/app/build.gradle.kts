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
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        // 앱 이름은 빌드 타입이 정한다 — 아래 debug 블록이 덮어쓴다.
        manifestPlaceholders["appLabel"] = "DROP"
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
        // 디버그 빌드는 **다른 앱으로** 깔린다 (BRU-209).
        //
        // 실기기에는 이미 실사용 DROP이 깔려 있다. 같은 applicationId로 디버그 빌드를
        // 밀면 서명이 달라 설치가 거부되고, 지우고 깔면 로그인 세션과 홈 화면에 올려 둔
        // 위젯 배치까지 함께 사라진다. 위젯을 실기기에서 확인하는 일은 앞으로도 반복되므로
        // 그때마다 실사용 앱을 인질로 잡지 않도록 여기서 갈라 둔다.
        debug {
            applicationIdSuffix = ".debug"
            manifestPlaceholders["appLabel"] = "DROP 개발"
        }
        // profile도 같은 자리에 깔린다. 디자인·성능을 실기기에서 볼 때 쓰는 것이
        // profile인데(디버그와 달리 AOT라 실제 속도가 나온다), 여기를 비워 두면
        // 기본 applicationId로 빌드돼 실사용 앱을 덮어쓴다 — debug만 막아 둔 것은
        // 반쪽짜리다.
        getByName("profile") {
            applicationIdSuffix = ".debug"
            manifestPlaceholders["appLabel"] = "DROP 개발"
        }
        release {
            signingConfig = if (releaseKeystoreFile != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

dependencies {
    testImplementation("junit:junit:4.13.2")
    // android.jar의 org.json은 메서드가 전부 예외를 던지는 껍데기다 — JVM 테스트에서
    // 실제 구현을 앞에 놓아야 위젯의 스냅샷 파싱을 에뮬레이터 없이 시험할 수 있다.
    testImplementation("org.json:json:20240303")
    // 위젯 갱신 경로는 기기에서만 확인할 수 있다 (AppWidgetManager·홈 화면 위젯).
    androidTestImplementation("androidx.test:runner:1.6.2")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
