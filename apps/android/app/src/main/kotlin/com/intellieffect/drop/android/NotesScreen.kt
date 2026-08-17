package com.intellieffect.drop.android

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.intellieffect.drop.core.NotesStore

/**
 * 스캐폴드용 최소 화면. 목록이 `:core`의 상태 홀더에서 그대로 흘러나오는지만 보여 준다.
 * 실제 홈 화면(필터 칩·선택 모드·작성)은 BRU-40에서 만든다.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NotesScreen(
    store: NotesStore,
    userEmail: String?,
    onSignOut: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val state by store.state.collectAsStateWithLifecycle()

    Scaffold(
        modifier = modifier.fillMaxSize(),
        topBar = {
            TopAppBar(
                title = { Text(userEmail ?: "DROP", style = MaterialTheme.typography.titleMedium) },
                actions = { TextButton(onClick = onSignOut) { Text("로그아웃") } },
            )
        },
    ) { insets ->
        when {
            state.isLoading -> CircularProgressIndicator(Modifier.padding(insets).padding(24.dp))

            state.errorMessage != null -> Text(
                text = state.errorMessage.orEmpty(),
                modifier = Modifier.padding(insets).padding(24.dp),
                style = MaterialTheme.typography.bodyLarge,
            )

            else -> LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(
                    top = insets.calculateTopPadding() + 12.dp,
                    bottom = insets.calculateBottomPadding() + 12.dp,
                    start = 16.dp,
                    end = 16.dp,
                ),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                items(state.visibleNotes, key = { it.id }) { note ->
                    Card {
                        Column(Modifier.padding(16.dp)) {
                            Text(note.content, style = MaterialTheme.typography.bodyLarge)
                            if (note.tags.isNotEmpty()) {
                                Text(
                                    text = note.tags.joinToString(" ") { "#${it.name}" },
                                    style = MaterialTheme.typography.labelMedium,
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}
