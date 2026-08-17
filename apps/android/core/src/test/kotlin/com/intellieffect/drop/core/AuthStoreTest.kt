package com.intellieffect.drop.core

import java.time.Instant
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertNull
import kotlin.test.assertTrue
import kotlinx.coroutines.test.runTest

/** iOS `AuthStoreTests`의 이식본. */
class AuthStoreTest {
    private val user = DropUser(id = "u1", email = "bruce@intellieffect.com")

    private fun session(user: DropUser = this.user) = Session(
        accessToken = "access",
        refreshToken = "refresh",
        expiresAt = Instant.ofEpochSecond(2_000_000_000),
        user = user,
    )

    private class FakeGateway(var restored: Session? = null) : AuthGateway {
        var signInResult: Result<Session> = Result.success(
            Session("a", "r", Instant.ofEpochSecond(2_000_000_000), DropUser("u1", null)),
        )
        var restoreError: Throwable? = null
        var signOutCount = 0
        var signOutError: Throwable? = null

        override suspend fun restore(): Session? {
            restoreError?.let { throw it }
            return restored
        }

        override suspend fun signIn(identity: GoogleIdentity): Session = signInResult.getOrThrow()

        override suspend fun signOut() {
            signOutCount += 1
            signOutError?.let { throw it }
        }
    }

    private class FakeIdentityProvider(
        var identity: GoogleIdentity? = GoogleIdentity(idToken = "id-token"),
    ) : GoogleIdentityProvider {
        var error: Throwable? = null
        var signOutCount = 0

        override suspend fun signIn(): GoogleIdentity? {
            error?.let { throw it }
            return identity
        }

        override fun signOut() {
            signOutCount += 1
        }
    }

    private fun store(
        gateway: FakeGateway = FakeGateway(),
        provider: FakeIdentityProvider = FakeIdentityProvider(),
    ) = Triple(AuthStore(gateway, provider), gateway, provider)

    /** 세션을 확인하기 전에는 로그인 화면도, 홈도 띄우지 않는다. */
    @Test
    fun `처음 상태는 미결정이다`() {
        val (store, _, _) = store()

        assertIs<AuthState.Undetermined>(store.state.value)
        assertNull(store.user)
    }

    @Test
    fun `저장된 세션이 있으면 로그인 상태로 복원된다`() = runTest {
        val (store, _, _) = store(FakeGateway(restored = session()))

        store.restore()

        assertEquals(user, (store.state.value as AuthState.SignedIn).user)
        assertEquals(user, store.user)
    }

    @Test
    fun `저장된 세션이 없으면 로그아웃 상태다`() = runTest {
        val (store, _, _) = store()

        store.restore()

        assertIs<AuthState.SignedOut>(store.state.value)
    }

    /**
     * 복원이 실패해도 오류 화면에 갇히면 안 된다 — 그러면 다시 로그인할 방법이 없다.
     */
    @Test
    fun `복원 실패는 로그인 화면으로 돌아간다`() = runTest {
        val gateway = FakeGateway()
        gateway.restoreError = AuthException.Network("끊김")
        val (store, _, _) = store(gateway)

        store.restore()

        assertIs<AuthState.SignedOut>(store.state.value)
    }

    @Test
    fun `구글 로그인이 성공하면 로그인 상태가 된다`() = runTest {
        val gateway = FakeGateway()
        gateway.signInResult = Result.success(session())
        val (store, _, _) = store(gateway)

        store.signInWithGoogle()

        assertEquals(user, (store.state.value as AuthState.SignedIn).user)
    }

    /** 사용자가 계정 선택 창을 닫은 것은 오류가 아니다. */
    @Test
    fun `취소는 오류가 아니라 로그아웃 복귀다`() = runTest {
        val (store, _, _) = store(provider = FakeIdentityProvider(identity = null))

        store.signInWithGoogle()

        assertIs<AuthState.SignedOut>(store.state.value)
    }

    @Test
    fun `서버가 거부하면 이유를 담은 실패 상태가 된다`() = runTest {
        val gateway = FakeGateway()
        gateway.signInResult = Result.failure(AuthException.Rejected("Unacceptable audience"))
        val (store, _, _) = store(gateway)

        store.signInWithGoogle()

        val failed = assertIs<AuthState.Failed>(store.state.value)
        assertTrue(failed.message.contains("Unacceptable audience"))
    }

    @Test
    fun `로그아웃하면 구글 세션까지 함께 끊는다`() = runTest {
        val gateway = FakeGateway(restored = session())
        val (store, _, provider) = store(gateway)
        store.restore()

        store.signOut()

        assertIs<AuthState.SignedOut>(store.state.value)
        assertEquals(1, gateway.signOutCount)
        assertEquals(1, provider.signOutCount)
    }

    /**
     * Supabase 로그아웃이 실패해도 로컬 로그아웃은 되어야 한다.
     * 여기서 멈추면 사용자가 로그아웃할 방법이 없어진다.
     */
    @Test
    fun `서버 로그아웃이 실패해도 로그아웃된다`() = runTest {
        val gateway = FakeGateway(restored = session())
        gateway.signOutError = AuthException.Network("끊김")
        val (store, _, provider) = store(gateway)
        store.restore()

        store.signOut()

        assertIs<AuthState.SignedOut>(store.state.value)
        assertEquals(1, provider.signOutCount)
    }
}
