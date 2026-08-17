package com.intellieffect.drop.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.intellieffect.drop.core.AuthState
import com.intellieffect.drop.core.AuthStore
import com.intellieffect.drop.core.InMemoryNotesRepository
import com.intellieffect.drop.core.NotesStore
import com.intellieffect.drop.core.sampleNotes
import kotlinx.coroutines.launch

/**
 * 앱 모듈은 조립만 한다 — 로직은 전부 `:core`에 있다.
 *
 * BRU-39에서 로그인이 붙었다. 로그인 뒤 목록은 아직 인메모리 표본이다 —
 * 실제 Supabase 노트 CRUD는 BRU-40.
 */
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val container = (application as DropApplication).container
        val authStore = AuthStore(
            gateway = container.authGateway,
            identityProvider = CredentialManagerIdentityProvider(
                activityContext = this,
                serverClientId = container.configuration.googleWebClientId,
            ),
        )

        setContent {
            MaterialTheme {
                RootScreen(authStore)
            }
        }
    }
}

@Composable
private fun RootScreen(authStore: AuthStore, modifier: Modifier = Modifier) {
    val state by authStore.state.collectAsStateWithLifecycle()
    val scope = rememberCoroutineScope()

    // 저장된 세션 확인은 이 컴포지션에서 한 번만.
    // (AuthStore가 Activity와 함께 만들어지므로 화면 회전 때는 다시 돈다 —
    //  저장소에서 읽어 오는 일이라 비싸지 않고, 그 사이에는 스피너가 보인다.
    //  ViewModel로 올리는 것은 BRU-40에서 화면 상태를 정리할 때 함께 한다.)
    LaunchedEffect(Unit) { authStore.restore() }

    when (val current = state) {
        // 아직 확인 전. 여기서 로그인 화면을 띄우면 이미 로그인된 사용자에게 깜빡인다.
        AuthState.Undetermined -> Box(
            modifier.fillMaxSize(),
            contentAlignment = Alignment.Center,
        ) { CircularProgressIndicator() }

        AuthState.Working, AuthState.SignedOut, is AuthState.Failed -> AuthScreen(
            isWorking = current == AuthState.Working,
            errorMessage = (current as? AuthState.Failed)?.message,
            onSignIn = { scope.launch { authStore.signInWithGoogle() } },
            modifier = modifier,
        )

        is AuthState.SignedIn -> {
            val notesStore = rememberNotesStore()
            NotesScreen(
                store = notesStore,
                userEmail = current.user.email,
                onSignOut = { scope.launch { authStore.signOut() } },
                modifier = modifier,
            )
        }
    }
}

/** BRU-40에서 Supabase 리포지토리로 갈아끼운다. */
@Composable
private fun rememberNotesStore(): NotesStore {
    val scope = rememberCoroutineScope()
    val store = androidx.compose.runtime.remember {
        NotesStore(InMemoryNotesRepository(sampleNotes()))
    }
    LaunchedEffect(store) { scope.launch { store.load() } }
    return store
}
