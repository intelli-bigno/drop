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
        // 과거 Flutter 앱이 쓰던 ID를 그대로 이어받는다 (iOS가 번들 ID를 이어받은 것과 같은 판단).
        // Google은 호출 앱을 (패키지명, 서명 SHA-1)로만 매칭하므로, 이 ID여야
        // bruce-clawdbot에 이미 등록된 Android OAuth 클라이언트로 로그인이 통과한다.
        // Play 등록·테스터도 이 ID에 붙어 있다. (BRU-39 판단, 배포는 BRU-42)
        applicationId = "com.intellieffect.drop.mobile"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "0.1.0"

        buildConfigField("String", "SUPABASE_URL", "\"${configValue("SUPABASE_URL")}\"")
        buildConfigField("String", "SUPABASE_ANON_KEY", "\"${configValue("SUPABASE_ANON_KEY")}\"")
        // Google 로그인의 serverClientId. **웹** 클라이언트 ID여야 한다 —
        // Supabase가 audience로 신뢰하는 것이 웹 클라이언트 하나뿐이다.
        buildConfigField(
            "String",
            "GOOGLE_WEB_CLIENT_ID",
            "\"${configValue("GOOGLE_WEB_CLIENT_ID")}\"",
        )
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

    // 실제 소켓을 쓰는 엔진은 앱에서만 물린다 — core는 엔진을 인자로 받는다.
    implementation(libs.ktor.client.okhttp)

    // Google 계정 선택 창. 화면을 띄우는 일이라 app 모듈의 몫이다.
    implementation(libs.androidx.credentials)
    implementation(libs.androidx.credentials.play.services)
    implementation(libs.google.id)

    // 첨부 썸네일 (서명 URL을 직접 불러온다)
    implementation(libs.coil.compose)
    implementation(libs.coil.network.okhttp)

    debugImplementation(libs.compose.ui.tooling)
}
