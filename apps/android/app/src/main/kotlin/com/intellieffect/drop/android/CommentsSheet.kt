package com.intellieffect.drop.android

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.intellieffect.drop.core.CommentsStore
import com.intellieffect.drop.core.Note
import com.intellieffect.drop.core.NoteComment
import com.intellieffect.drop.core.RelativeTimeFormatter
import kotlinx.coroutines.launch

/**
 * 한 노트의 댓글을 읽고 쓰는 자리 (BRU-86, iOS `CommentsSheet`와 같은 사양).
 *
 * 시트로 띄우는 이유: 댓글은 노트를 보다가 잠깐 덧붙이는 것이지 다른 화면으로
 * 넘어가는 일이 아니다. 목록 → 노트 → 댓글 → 닫기로 원래 자리에 돌아온다.
 *
 * **댓글은 노트가 아니다.** 여기서 쓴 것은 `note_comments` 에만 들어가고
 * 노트 목록·검색·Inbox·위젯 어디에도 나타나지 않는다 (BRU-62의 별도 테이블 설계).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CommentsSheet(
    note: Note,
    store: CommentsStore,
    onDismiss: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val state by store.state.collectAsStateWithLifecycle()
    val scope = rememberCoroutineScope()
    val formatter = remember { RelativeTimeFormatter() }
    var draft by remember(note.id) { mutableStateOf("") }

    LaunchedEffect(note.id) { store.load(note.id) }

    val comments = state.comments(note.id)

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState) {
        Column(
            modifier = Modifier.fillMaxWidth().padding(16.dp).imePadding(),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            // 어느 노트에 다는 댓글인지 늘 보이게 둔다 — 시트만 보면 맥락이 사라진다.
            Text(
                text = note.content.ifBlank { "(빈 노트)" },
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )

            HorizontalDivider()

            when {
                comments.isEmpty() && state.isLoading -> Box(
                    Modifier.fillMaxWidth().padding(24.dp),
                    contentAlignment = Alignment.Center,
                ) { CircularProgressIndicator() }

                comments.isEmpty() -> Box(
                    Modifier.fillMaxWidth().padding(24.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = "댓글이 없습니다",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }

                else -> LazyColumn(
                    modifier = Modifier.fillMaxWidth().heightIn(max = 320.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    items(comments, key = { it.id }) { comment ->
                        CommentRow(
                            comment = comment,
                            relativeTime = formatter.format(comment.createdAt),
                            // 댓글에는 휴지통이 없다 — 지우면 바로 사라진다.
                            onDelete = { scope.launch { store.delete(comment.id, note.id) } },
                        )
                    }
                }
            }

            HorizontalDivider()

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                OutlinedTextField(
                    value = draft,
                    onValueChange = { draft = it },
                    modifier = Modifier.weight(1f),
                    placeholder = { Text("댓글 쓰기") },
                )
                Button(
                    enabled = draft.isNotBlank(),
                    onClick = {
                        val body = draft
                        // 입력창은 즉시 비운다 — 낙관적 삽입과 같은 이유로, 보낸 것이
                        // 두 군데 남아 있으면 방금 무엇을 썼는지 헷갈린다.
                        draft = ""
                        scope.launch { store.add(note.id, body) }
                    },
                ) { Text("쓰기") }
            }

            state.errorMessage?.let { message ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = message,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.error,
                        modifier = Modifier.weight(1f),
                    )
                    TextButton(onClick = store::dismissError) { Text("확인") }
                }
            }

            TextButton(onClick = onDismiss, modifier = Modifier.align(Alignment.End)) {
                Text("닫기")
            }
        }
    }
}

@Composable
private fun CommentRow(
    comment: NoteComment,
    relativeTime: String,
    onDelete: () -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.Top,
    ) {
        Column(Modifier.weight(1f)) {
            Text(text = comment.body, style = MaterialTheme.typography.bodyMedium)
            Text(
                text = relativeTime,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        TextButton(onClick = onDelete) { Text("삭제") }
    }
}
