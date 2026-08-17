package com.intellieffect.drop.core

import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.request.header
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.http.ContentType
import io.ktor.http.HttpStatusCode
import io.ktor.http.contentType
import io.ktor.http.isSuccess
import java.time.Clock
import java.time.Instant
import kotlin.coroutines.cancellation.CancellationException
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/**
 * `AuthGateway` + `AuthTokenProvider`의 실제 구현. Supabase GoTrue REST를 직접 부른다.
 *
 * SDK 대신 REST를 쓰는 이유는 BRU-39에 적었다 — supabase-kt의 세션 영속화가 Android
 * Context를 요구해서, `core`가 순수 JVM으로 남지 못한다.
 */
class SupabaseAuthGateway(
    private val config: DropConfiguration,
    private val client: HttpClient,
    private val storage: SessionStorage,
    private val clock: Clock = Clock.systemUTC(),
) : AuthGateway, AuthTokenProvider {
    // 여러 화면이 동시에 토큰을 물어도 갱신은 한 번만 나가야 한다.
    // 두 번 나가면 먼저 쓴 리프레시 토큰이 무효가 되어 두 번째가 로그아웃을 유발한다.
    private val mutex = Mutex()
    private var session: Session? = storage.load()

    val currentSession: Session? get() = session

    override val userId: String? get() = session?.user?.id

    override suspend fun restore(): Session? = mutex.withLock {
        val stored = session ?: storage.load()?.also { session = it } ?: return null
        if (!stored.isExpired(clock.instant())) return stored

        // 앱을 며칠 만에 켜면 액세스 토큰은 이미 죽어 있다. 리프레시가 안 되면
        // 남은 세션은 쓸 수 없으므로 버리고 로그아웃 상태로 돌아간다.
        return try {
            refreshLocked(stored.refreshToken)
        } catch (cancellation: CancellationException) {
            throw cancellation
        } catch (_: AuthException.Rejected) {
            discard()
            null
        }
    }

    override suspend fun signIn(identity: GoogleIdentity): Session = mutex.withLock {
        val response = request(
            grantType = "id_token",
            body = buildJsonObject {
                put("provider", "google")
                put("id_token", identity.idToken)
                identity.accessToken?.let { put("access_token", it) }
            },
        )
        store(response)
    }

    override suspend fun signOut() {
        val token = session?.accessToken
        // 로컬 세션을 먼저 끊는다. 서버 호출이 실패해도 로그아웃은 되어야 한다 —
        // 안 그러면 사용자가 로그아웃할 방법이 없어진다.
        discard()
        if (token == null) return
        runCatching {
            client.post("${config.supabaseUrl}/auth/v1/logout") {
                header("apikey", config.supabaseAnonKey)
                header("Authorization", "Bearer $token")
            }
        }
    }

    override suspend fun accessToken(): String? = mutex.withLock {
        val current = session ?: return null
        if (!current.isExpired(clock.instant())) return current.accessToken

        return try {
            refreshLocked(current.refreshToken).accessToken
        } catch (cancellation: CancellationException) {
            throw cancellation
        } catch (_: AuthException.Rejected) {
            discard()
            null
        }
    }

    // MARK: - 내부

    /** 이미 [mutex]를 쥔 상태에서만 부른다. */
    private suspend fun refreshLocked(refreshToken: String): Session = store(
        request(
            grantType = "refresh_token",
            body = buildJsonObject { put("refresh_token", refreshToken) },
        ),
    )

    private suspend fun request(grantType: String, body: JsonObject): TokenResponse {
        val response = try {
            client.post("${config.supabaseUrl}/auth/v1/token?grant_type=$grantType") {
                header("apikey", config.supabaseAnonKey)
                contentType(ContentType.Application.Json)
                setBody(body)
            }
        } catch (cancellation: CancellationException) {
            throw cancellation
        } catch (error: Throwable) {
            throw AuthException.Network(error.message ?: error.toString())
        }

        if (!response.status.isSuccess()) {
            val message = response.supabaseErrorMessage()
            // 5xx는 서버가 잠깐 흔들린 것 — 재로그인해도 달라지지 않는다.
            // 4xx만 "거절"로 다뤄 세션을 버린다.
            throw if (response.status.value >= HttpStatusCode.InternalServerError.value) {
                AuthException.Network(message)
            } else {
                AuthException.Rejected(message)
            }
        }

        return try {
            response.body()
        } catch (error: Throwable) {
            throw AuthException.Decoding(error.message ?: error.toString())
        }
    }

    private fun store(response: TokenResponse): Session {
        val user = response.user ?: throw AuthException.Decoding("응답에 사용자가 없습니다")
        val session = Session(
            accessToken = response.accessToken,
            refreshToken = response.refreshToken,
            // expires_at(절대 시각)이 오면 그것을, 없으면 expires_in으로 계산한다.
            expiresAt = response.expiresAt?.let(Instant::ofEpochSecond)
                ?: clock.instant().plusSeconds(response.expiresIn ?: 3600),
            user = DropUser(id = user.id, email = user.email),
        )
        this.session = session
        storage.save(session)
        return session
    }

    private fun discard() {
        session = null
        storage.clear()
    }
}

@Serializable
internal data class TokenResponse(
    @SerialName("access_token") val accessToken: String,
    @SerialName("refresh_token") val refreshToken: String,
    @SerialName("expires_in") val expiresIn: Long? = null,
    @SerialName("expires_at") val expiresAt: Long? = null,
    val user: UserResponse? = null,
) {
    @Serializable
    internal data class UserResponse(val id: String, val email: String? = null)
}
