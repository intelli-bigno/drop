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

/**
 * 서명 값. 비밀값이라 `local.properties`가 아니라 **`key.properties`** 를 본다 —
 * 둘을 섞으면 Supabase 구성값과 키스토어 비밀번호가 한 파일에 살게 된다.
 * 두 파일 모두 커밋되지 않는다.
 */
val keyProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

fun releaseValue(name: String): String? =
    System.getenv(name)?.takeIf { it.isNotBlank() }
        ?: keyProperties.getProperty(name)?.takeIf { it.isNotBlank() }

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
        // CI가 시간 기반 값을 넘긴다 (`-PversionCode=…`). 로컬 빌드는 1로 둔다.
        //
        // iOS처럼 `yyMMddHHmm`을 쓰면 안 된다 — Play의 versionCode 상한이
        // 2,100,000,000이고 그 값(2608…)은 넘는다. release.yml이 "2025-01-01 이후 분"으로
        // 만든다: 단조 증가하고, Flutter 시절 run_number 기반 값보다 항상 크다.
        versionCode = (project.findProperty("versionCode") as String?)?.toIntOrNull() ?: 1
        versionName = (project.findProperty("versionName") as String?) ?: "0.1.0"

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

    /**
     * 릴리스 서명. 값은 환경변수 → `key.properties` 순으로 찾는다 (CI는 환경변수만 넣는다).
     *
     * 키스토어가 없으면 **디버그 키로** 서명한다. 서명 설정을 그냥 비워 두면 산출물이
     * `app-release-unsigned.apk`가 되어 설치조차 되지 않는다(실측). 로컬에서 릴리스
     * 빌드를 눌러 보는 길을 막지 않기 위한 폴백이고,
     * CI에서는 `release.yml`이 apksigner로 지문을 대조해 디버그 키 서명을 실패로 끊는다
     * (Google 로그인은 등록된 릴리스 SHA-1로만 통과하므로, 지문이 어긋난 빌드를
     * 테스터에게 보내면 "로그인만 안 되는 빌드"가 나간다).
     */
    val keystorePath = releaseValue("ANDROID_KEYSTORE_FILE")
    val hasReleaseKeystore = keystorePath != null && file(keystorePath).exists()

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = file(keystorePath!!)
                storePassword = releaseValue("ANDROID_STORE_PASSWORD")
                keyAlias = releaseValue("ANDROID_KEY_ALIAS")
                keyPassword = releaseValue("ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (hasReleaseKeystore) "release" else "debug")
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

    // 홈 화면 위젯
    implementation(libs.androidx.glance.appwidget)
    implementation(libs.androidx.glance.material3)

    debugImplementation(libs.compose.ui.tooling)
}
