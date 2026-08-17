package com.intellieffect.drop.core

import kotlin.coroutines.cancellation.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/** iOS `AuthState`와 같은 상태 집합. */
sealed interface AuthState {
    /**
     * 아직 저장된 세션을 확인하기 전. 이 상태에서 로그인 화면을 띄우면
     * 이미 로그인된 사용자에게 로그인 화면이 깜빡인다.
     */
    data object Undetermined : AuthState
    data object Working : AuthState
    data object SignedOut : AuthState
    data class SignedIn(val user: DropUser) : AuthState
    data class Failed(val message: String) : AuthState
}

/** iOS `AuthStore`의 이식본. Android SDK에 의존하지 않아 JVM 테스트로 덮인다. */
class AuthStore(
    private val gateway: AuthGateway,
    private val identityProvider: GoogleIdentityProvider,
) {
    private val _state = MutableStateFlow<AuthState>(AuthState.Undetermined)
    val state: StateFlow<AuthState> = _state.asStateFlow()

    val user: DropUser? get() = (_state.value as? AuthState.SignedIn)?.user

    /** 앱 시작 시 저장된 세션을 확인한다. */
    suspend fun restore() {
        _state.value = try {
            gateway.restore()?.let { AuthState.SignedIn(it.user) } ?: AuthState.SignedOut
        } catch (cancellation: CancellationException) {
            throw cancellation
        } catch (error: Throwable) {
            // 복원 실패는 로그인 화면으로 돌아가면 되는 일이다. 오류 화면에 갇히면
            // 사용자가 다시 로그인할 방법이 없어진다.
            AuthState.SignedOut
        }
    }

    suspend fun signInWithGoogle() {
        _state.value = AuthState.Working
        _state.value = try {
            // null은 사용자가 창을 닫은 것 — 오류로 만들지 않고 로그인 화면으로 돌아간다.
            val identity = identityProvider.signIn()
                ?: return run { _state.value = AuthState.SignedOut }
            AuthState.SignedIn(gateway.signIn(identity).user)
        } catch (cancellation: CancellationException) {
            _state.value = AuthState.SignedOut
            throw cancellation
        } catch (error: Throwable) {
            AuthState.Failed(messageFor(error))
        }
    }

    suspend fun signOut() {
        // 게이트웨이가 로컬 세션을 먼저 끊으므로 여기서 실패를 삼켜도 로그아웃은 된다.
        runCatching { gateway.signOut() }
        identityProvider.signOut()
        _state.value = AuthState.SignedOut
    }

    private fun messageFor(error: Throwable): String = when (error) {
        is AuthException.Rejected -> "로그인이 거부됐습니다: ${error.reason}"
        is AuthException.Network -> "네트워크에 연결하지 못했습니다."
        is AuthException.Decoding -> "응답을 이해하지 못했습니다."
        else -> error.message ?: error.toString()
    }
}
