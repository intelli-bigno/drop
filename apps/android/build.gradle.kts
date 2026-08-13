// 루트는 플러그인을 선언만 하고 적용하지 않는다 — 적용은 각 모듈에서.
plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.kotlin.android) apply false
    alias(libs.plugins.kotlin.jvm) apply false
    alias(libs.plugins.kotlin.compose) apply false
}
