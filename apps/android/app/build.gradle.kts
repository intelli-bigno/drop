import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
}

/**
 * 구성값이 흐르는 경로 (iOS의 xcconfig 경로와 같은 자리):
 *
 *   환경변수 → gradle 속성(-P / gradle.properties) → local.properties → BuildConfig
 *
 * 실제 값이 든 local.properties는 커밋되지 않는다. `make android-config`가 만든다.
 */
val localProperties = Properties().apply {
    val file = rootProject.file("local.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

fun configValue(name: String): String =
    System.getenv(name)
        ?: (project.findProperty(name) as String?)?.takeIf { it.isNotBlank() }
        ?: localProperties.getProperty(name)
        ?: ""

android {
    namespace = "com.intellieffect.drop.android"
    compileSdk = 35

    defaultConfig {
        // Flutter 앱(com.intellieffect.drop.mobile)과 다른 ID를 쓴다 — 병렬 운영 기간 동안
        // 한 기기에 둘 다 깔릴 수 있어야 한다. iOS 트랙의 `.next` 접미사와 같은 이유.
        applicationId = "com.intellieffect.drop.android"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "0.1.0"

        buildConfigField("String", "SUPABASE_URL", "\"${configValue("SUPABASE_URL")}\"")
        buildConfigField("String", "SUPABASE_ANON_KEY", "\"${configValue("SUPABASE_ANON_KEY")}\"")
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
}

dependencies {
    // 로직은 전부 여기에 있다. app 모듈은 조립만 한다.
    implementation(project(":core"))

    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.material3)
    implementation(libs.compose.ui.tooling.preview)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)

    debugImplementation(libs.compose.ui.tooling)
}
