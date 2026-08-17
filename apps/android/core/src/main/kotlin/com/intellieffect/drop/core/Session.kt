package com.intellieffect.drop.core

import java.time.Duration
import java.time.Instant

data class DropUser(val id: String, val email: String?)

/**
 * 로그인 세션. 액세스 토큰은 한 시간쯤 살고, 리프레시 토큰으로 갱신한다.
 * (Supabase SDK가 하던 일을 직접 들고 있는 것 — 이유는 BRU-39 참조)
 */
data class Session(
    val accessToken: String,
    val refreshToken: String,
    val expiresAt: Instant,
    val user: DropUser,
) {
    /**
     * 만료 [leeway]초 전부터 만료로 본다. 정확히 만료 직전에 요청을 보내면
     * 서버에 닿는 순간 이미 만료된 토큰이 되기 때문이다.
     */
    fun isExpired(now: Instant, leeway: Duration = DEFAULT_LEEWAY): Boolean =
        !now.plus(leeway).isBefore(expiresAt)

    companion object {
        val DEFAULT_LEEWAY: Duration = Duration.ofSeconds(60)
    }
}

/**
 * 세션을 앱 재시작 후에도 남겨 두는 자리. 구현은 `app` 모듈(SharedPreferences)에 있고,
 * `core`는 인터페이스만 알기 때문에 만료·갱신 판정을 JVM 테스트로 덮을 수 있다.
 */
interface SessionStorage {
    fun load(): Session?
    fun save(session: Session)
    fun clear()
}

/** 테스트·프리뷰용. */
class InMemorySessionStorage(private var session: Session? = null) : SessionStorage {
    override fun load(): Session? = session
    override fun save(session: Session) {
        this.session = session
    }

    override fun clear() {
        session = null
    }
}
