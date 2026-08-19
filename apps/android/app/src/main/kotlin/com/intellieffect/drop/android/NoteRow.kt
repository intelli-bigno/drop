package com.intellieffect.drop.android

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.Text
import androidx.compose.material3.rememberSwipeToDismissBoxState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.intellieffect.drop.core.Note
import com.intellieffect.drop.core.NoteViewMode
import com.intellieffect.drop.core.RelativeTimeFormatter

/**
 * 목록의 한 줄. iOS BRU-49에서 정한 모양을 따른다 — 본문 한 줄 + 시각 + 태그.
 * 카드가 아니라 줄이어야 한 화면에 더 많이 들어온다.
 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun NoteRow(
    note: Note,
    isSelected: Boolean,
    onClick: () -> Unit,
    onLongClick: () -> Unit,
    modifier: Modifier = Modifier,
    /** 이 노트에 달린 댓글 수. 0이면 아무것도 그리지 않는다 (BRU-86). */
    commentCount: Int = 0,
) {
    val formatter = remember { RelativeTimeFormatter() }

    Row(
        modifier = modifier
            .fillMaxWidth()
            .background(
                if (isSelected) MaterialTheme.colorScheme.secondaryContainer
                else MaterialTheme.colorScheme.surface,
            )
            .combinedClickable(onClick = onClick, onLongClick = onLongClick)
            .padding(horizontal = 16.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (note.isPinned) Text("📌", style = MaterialTheme.typography.labelMedium)

        Column(Modifier.weight(1f)) {
            Text(
                // 여러 줄 노트도 목록에서는 첫 줄만 보여 준다 — 줄 높이가 흔들리면
                // 목록을 훑는 눈이 걸린다.
                text = note.content.lineSequence().firstOrNull { it.isNotBlank() }
                    ?: note.content.ifBlank { "(빈 노트)" },
                style = MaterialTheme.typography.bodyLarge,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            if (note.tags.isNotEmpty()) {
                Text(
                    text = note.tags.joinToString(" ") { "#${it.name}" },
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.primary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }

        if (note.attachments.isNotEmpty()) {
            Text("📎${note.attachments.size}", style = MaterialTheme.typography.labelSmall)
        }

        // 댓글 뱃지. 첨부와 같은 자리에 두어 "이 노트에 뭐가 더 붙어 있다"가
        // 한 눈에 보이게 한다.
        if (commentCount > 0) {
            Text(
                text = "💬$commentCount",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.semantics { contentDescription = "댓글 ${commentCount}개" },
            )
        }

        Text(
            text = formatter.format(note.createdAt),
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

/**
 * 스와이프 동작. 뷰모드마다 뜻이 달라야 한다 —
 * 휴지통에서 왼쪽으로 밀면 "되살리기", 활성 목록에서는 "보관".
 */
@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun SwipeableNoteRow(
    note: Note,
    viewMode: NoteViewMode,
    isSelected: Boolean,
    onClick: () -> Unit,
    onLongClick: () -> Unit,
    onSwipeStart: () -> Unit,
    onSwipeEnd: () -> Unit,
    modifier: Modifier = Modifier,
    commentCount: Int = 0,
) {
    val state = rememberSwipeToDismissBoxState()

    // 스와이프가 끝나면 제자리로 돌려놓는다. 낙관적 갱신으로 줄이 사라지기 때문에
    // 남겨 두면 되돌아온 줄(실패 시)이 이미 밀린 상태로 나타난다.
    LaunchedEffect(state.currentValue) {
        when (state.currentValue) {
            SwipeToDismissBoxValue.StartToEnd -> {
                onSwipeStart()
                state.reset()
            }

            SwipeToDismissBoxValue.EndToStart -> {
                onSwipeEnd()
                state.reset()
            }

            SwipeToDismissBoxValue.Settled -> Unit
        }
    }

    SwipeToDismissBox(
        state = state,
        modifier = modifier,
        backgroundContent = {
            // 라벨 색을 **배경과 짝지어** 정한다. 예전처럼 색을 물려받게 두면
            // 팔레트를 갈아 끼울 때마다 onSurface 글자가 엉뚱한 배경 위에 놓여
            // 대비가 조용히 무너진다 (BRU-76에서 실제로 확인한 함정).
            val (background, label, alignment) = when (state.dismissDirection) {
                SwipeToDismissBoxValue.StartToEnd -> Triple(
                    SwipeBackground(
                        MaterialTheme.colorScheme.tertiaryContainer,
                        MaterialTheme.colorScheme.onTertiaryContainer,
                    ),
                    startLabel(viewMode),
                    Alignment.CenterStart,
                )

                SwipeToDismissBoxValue.EndToStart -> Triple(
                    SwipeBackground(
                        MaterialTheme.colorScheme.errorContainer,
                        MaterialTheme.colorScheme.onErrorContainer,
                    ),
                    endLabel(viewMode),
                    Alignment.CenterEnd,
                )

                SwipeToDismissBoxValue.Settled -> Triple(
                    SwipeBackground(
                        MaterialTheme.colorScheme.surface,
                        MaterialTheme.colorScheme.onSurface,
                    ),
                    "",
                    Alignment.Center,
                )
            }
            Box(
                Modifier.fillMaxSize().background(background.container),
                contentAlignment = alignment,
            ) {
                Text(
                    text = label,
                    modifier = Modifier.padding(horizontal = 20.dp),
                    color = background.onContainer,
                    fontWeight = FontWeight.Medium,
                )
            }
        },
    ) {
        NoteRow(note, isSelected, onClick, onLongClick, commentCount = commentCount)
    }
}

/** 스와이프 배경과 그 위 글자색은 항상 한 쌍으로 움직인다. */
private data class SwipeBackground(val container: Color, val onContainer: Color)

private fun startLabel(viewMode: NoteViewMode) = when (viewMode) {
    NoteViewMode.ACTIVE -> "고정"
    NoteViewMode.ARCHIVED -> "보관 해제"
    NoteViewMode.TRASH -> "되살리기"
}

private fun endLabel(viewMode: NoteViewMode) = when (viewMode) {
    NoteViewMode.ACTIVE -> "보관"
    NoteViewMode.ARCHIVED -> "휴지통"
    NoteViewMode.TRASH -> "영구 삭제"
}
