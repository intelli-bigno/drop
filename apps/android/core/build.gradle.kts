import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    alias(libs.plugins.kotlin.jvm)
}

// 이 모듈에는 Android 의존이 하나도 없다. 에뮬레이터도 SDK도 없이
// `./gradlew :core:test`가 도는 상태를 유지하는 것이 TDD 사이클의 전제다.
dependencies {
    implementation(libs.kotlinx.coroutines.core)

    testImplementation(kotlin("test"))
    testImplementation(libs.kotlinx.coroutines.test)
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
