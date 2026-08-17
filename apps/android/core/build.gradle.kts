import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    alias(libs.plugins.kotlin.jvm)
    alias(libs.plugins.kotlin.serialization)
    `java-library`
}

// 이 모듈에는 Android 의존이 하나도 없다. 에뮬레이터도 SDK도 없이
// `./gradlew :core:test`가 도는 상태를 유지하는 것이 TDD 사이클의 전제다.
dependencies {
    // StateFlow가 NotesStore의 공개 API에 나온다 — 쓰는 쪽도 봐야 하므로 api.
    api(libs.kotlinx.coroutines.core)

    // Ktor client는 JVM에서도 Android에서도 같은 코드로 돈다 —
    // 그래서 Supabase 호출을 이 순수 JVM 모듈에 둘 수 있다.
    api(libs.ktor.client.core)
    implementation(libs.ktor.client.content.negotiation)
    implementation(libs.ktor.serialization.kotlinx.json)
    implementation(libs.kotlinx.serialization.json)

    testImplementation(kotlin("test"))
    testImplementation(libs.kotlinx.coroutines.test)
    // 테스트는 실제 네트워크 없이 응답을 흉내낸다.
    testImplementation(libs.ktor.client.mock)
}

// toolchain을 고정하지 않는다 — 고정하면 JDK 17이 없는 기계에서 다운로드부터 막힌다.
// 대신 산출 바이트코드만 17에 맞춘다 (app 모듈이 그대로 삼킬 수 있어야 한다).
java {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

tasks.test {
    useJUnitPlatform()
    testLogging {
        events("passed", "failed", "skipped")
    }
}
