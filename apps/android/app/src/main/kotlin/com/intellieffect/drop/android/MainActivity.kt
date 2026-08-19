package com.intellieffect.drop.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.intellieffect.drop.core.AuthState
import kotlinx.coroutines.launch

/**
 * 앱 모듈은 조립만 한다 — 로직은 전부 `:core`에 있다.
 *
 * BRU-39에서 로그인, BRU-40에서 실제 Supabase 노트 목록이 붙었다.
 * 태그 편집·첨부는 BRU-41.
 */
class MainActivity : ComponentActivity() {
    companion object {
        /** 위젯의 ＋ 로 들어왔다는 표시. 목록을 보여 주기 전에 작성 시트를 띄운다. */
        const val EXTRA_START_COMPOSER = "com.intellieffect.drop.START_COMPOSER"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val startComposer = intent?.getBooleanExtra(EXTRA_START_COMPOSER, false) == true

        setContent {
            DropTheme {
                val viewModel: DropViewModel = viewModel()
                // 계정 선택 창은 Activity가 있어야 뜬다. ViewModel은 Activity보다 오래
                // 살기 때문에 들고 있으면 누수다 — 화면이 붙어 있는 동안만 빌려 주고
                // 떨어질 때 반드시 놓는다.
                DisposableEffect(Unit) {
                    viewModel.attach(this@MainActivity)
                    onDispose { viewModel.detach() }
                }
                RootScreen(viewModel, startComposer = startComposer)
            }
        }
    }
}

@Composable
private fun RootScreen(
    viewModel: DropViewModel,
    startComposer: Boolean,
    modifier: Modifier = Modifier,
) {
    val authState by viewModel.authStore.state.collectAsStateWithLifecycle()
    val scope = rememberCoroutineScope()

    LaunchedEffect(Unit) { viewModel.authStore.restore() }

    when (val current = authState) {
        // 아직 확인 전. 여기서 로그인 화면을 띄우면 이미 로그인된 사용자에게 깜빡인다.
        AuthState.Undetermined -> Box(
            modifier.fillMaxSize(),
            contentAlignment = Alignment.Center,
        ) { CircularProgressIndicator() }

        AuthState.Working, AuthState.SignedOut, is AuthState.Failed -> AuthScreen(
            isWorking = current == AuthState.Working,
            errorMessage = (current as? AuthState.Failed)?.message,
            onSignIn = { scope.launch { viewModel.authStore.signInWithGoogle() } },
            modifier = modifier,
        )

        is AuthState.SignedIn -> {
            // 로그인한 사용자가 바뀌면 목록을 다시 불러야 한다 —
            // 남겨 두면 앞 사용자의 노트가 잠깐 보인다.
            LaunchedEffect(current.user.id) { viewModel.notesStore.load() }

            HomeScreen(
                store = viewModel.notesStore,
                userEmail = current.user.email,
                urlCache = viewModel.signedUrlCache,
                onSignOut = { viewModel.signOut() },
                onAddTag = viewModel::addTag,
                onRemoveTag = viewModel::removeTag,
                onAddAttachment = viewModel::addAttachment,
                onRemoveAttachment = viewModel::removeAttachment,
                startComposer = startComposer,
                modifier = modifier,
            )
        }
    }
}
