package com.intellieffect.drop.core

/** 인증 경로의 실패. 문구는 [AuthStore]가 붙인다. */
sealed class AuthException(message: String) : Exception(message) {
    class Network(val reason: String) : AuthException(reason)

    /** Supabase가 요청을 거절했다 (audience 불일치, 만료된 리프레시 토큰 등). */
    class Rejected(val reason: String) : AuthException(reason)
    class Decoding(val reason: String) : AuthException(reason)
}

/** Google에서 받아온 자격증명. */
data class GoogleIdentity(val idToken: String, val accessToken: String? = null)

/**
 * Google 로그인 창을 띄우는 쪽. 화면·Activity가 필요한 SDK 호출은 `app` 모듈이 맡고,
 * `core`는 결과 토큰만 받는다 (iOS `GoogleIdentityProvider`와 같은 경계).
 *
 * `null` 반환은 **사용자 취소**를 뜻한다 — 오류가 아니다.
 */
interface GoogleIdentityProvider {
    suspend fun signIn(): GoogleIdentity?
    fun signOut()
}

/** Supabase 인증에 대한 얇은 경계. 테스트에서 통째로 갈아끼운다. */
interface AuthGateway {
    /** 저장된 세션을 되살린다. 만료됐으면 갱신을 시도하고, 실패하면 세션을 버린다. */
    suspend fun restore(): Session?
    suspend fun signIn(identity: GoogleIdentity): Session
    suspend fun signOut()
}

/**
 * 데이터 호출이 쓰는 토큰 공급자. 만료가 가까우면 알아서 갱신한다 —
 * 호출하는 쪽(노트 리포지토리)이 만료를 신경 쓰지 않도록.
 */
interface AuthTokenProvider {
    /** 유효한 액세스 토큰. 세션이 없으면 `null`. */
    suspend fun accessToken(): String?
    val userId: String?
}
