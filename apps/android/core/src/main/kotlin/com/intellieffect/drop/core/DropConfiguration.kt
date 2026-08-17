package com.intellieffect.drop.core

/** 빌드 구성값이 잘못 흘러 들어온 경우. 앱 시작 시점에 확실히 끊는다. */
sealed class DropConfigurationException(message: String) : Exception(message) {
    /** 키가 없거나 공백뿐인 값이 들어왔다. */
    class MissingValue(val key: String) : DropConfigurationException("구성값이 비어 있습니다: $key")

    /** 스킴이나 호스트가 없는 URL. */
    class MalformedUrl(val value: String) : DropConfigurationException("URL 형식이 아닙니다: $value")
}

/**
 * 앱이 보는 Supabase와 Google 클라이언트.
 *
 * 값이 흐르는 경로는 `.env.local` → `scripts/android-config.sh` → `local.properties`
 * → `BuildConfig` → 이 타입이다. iOS의 `DropConfiguration`(xcconfig → Info.plist)과 같은 자리.
 *
 * 읽는 지점을 맵 하나로 좁혀 두어 Android 프레임워크 없이 검증한다.
 */
data class DropConfiguration(
    val supabaseUrl: String,
    val supabaseAnonKey: String,
    /**
     * Google 로그인에 `serverClientId`로 넘길 값. **웹** 클라이언트 ID여야 한다 —
     * Supabase Google provider가 audience로 신뢰하는 것이 웹 클라이언트 하나뿐이어서,
     * Android 클라이언트 ID를 넣으면 `Unacceptable audience`로 거부된다.
     */
    val googleWebClientId: String,
) {
    companion object {
        fun from(values: Map<String, String?>): DropConfiguration {
            val url = require(values, "SUPABASE_URL")

            // `https://` 없이 호스트만 들어오는 사고가 잦다(빌드 스크립트가 값을 자르는 경우).
            // 그대로 두면 첫 네트워크 호출에서야 알게 되므로 여기서 끊는다.
            if (!URL_PATTERN.matches(url)) throw DropConfigurationException.MalformedUrl(url)

            return DropConfiguration(
                // 뒤에 슬래시가 붙어 오면 경로를 이어 붙일 때 `//`가 된다.
                supabaseUrl = url.trimEnd('/'),
                supabaseAnonKey = require(values, "SUPABASE_ANON_KEY"),
                googleWebClientId = require(values, "GOOGLE_WEB_CLIENT_ID"),
            )
        }

        private val URL_PATTERN = Regex("^https?://[^/\\s]+(/.*)?$")

        private fun require(values: Map<String, String?>, key: String): String {
            val value = values[key]?.trim()
            if (value.isNullOrEmpty()) throw DropConfigurationException.MissingValue(key)
            return value
        }
    }
}
