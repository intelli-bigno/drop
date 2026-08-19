package com.intellieffect.drop.android

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AssistChip
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.SuggestionChip
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.intellieffect.drop.core.Note
import com.intellieffect.drop.core.NoteViewMode
import com.intellieffect.drop.core.RelativeTimeFormatter
import com.intellieffect.drop.core.SignedUrlCache

/**
 * 노트를 **펼쳐 보는** 자리 (BRU-77). 행을 탭하면 여기가 열린다.
 *
 * 왜 편집기가 아니라 뷰어인가 — 데스크톱에서 노트를 펼치기만 해도 에디터의 직렬화가
 * 원문을 덮어쓴 사고가 있었다(BRU-66). "탭 = 편집기 열기"는 취향 문제가 아니라
 * **원문 보존의 위험 경로**다. 열어 보려던 동작이 저장 경로를 건드리면 안 된다.
 *
 * 그래서 이 화면은 **읽기 전용 경로**다. 인자 목록에 저장 콜백이 아예 없다 —
 * 없는 것은 실수로도 부를 수 없다. 노트를 바꾸는 일(편집·보관·휴지통)은 전부
 * 여기서 시트를 닫고 밖에서 벌어진다.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NoteViewerSheet(
    note: Note,
    viewMode: NoteViewMode,
    urlCache: SignedUrlCache,
    commentCount: Int,
    onDismiss: () -> Unit,
    onEdit: () -> Unit,
    onComments: () -> Unit,
    onArchive: () -> Unit,
    onTrash: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val formatter = remember { RelativeTimeFormatter() }

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState) {
        Column(
            modifier = Modifier.fillMaxWidth().padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                if (note.isPinned) Text("📌", style = MaterialTheme.typography.labelMedium)
                Text(
                    text = formatter.format(note.createdAt),
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.weight(1f),
                )
                // 댓글은 노트가 아니다 — 노트 옆에 붙는 것이라 진입도 따로 둔다 (BRU-86).
                TextButton(onClick = onComments) {
                    Text(if (commentCount > 0) "💬 $commentCount" else "💬 댓글")
                }
            }

            HorizontalDivider()

            // 본문 **전문**을 줄바꿈 그대로 보여 준다. 목록은 첫 줄만 보여 주므로
            // 여러 줄 노트를 통째로 읽을 수 있는 자리는 여기 하나뿐이다.
            Text(
                text = note.content.ifBlank { "(빈 노트)" },
                style = MaterialTheme.typography.bodyLarge,
                // 긴 노트는 본문만 스크롤한다 — 액션 줄이 화면 밖으로 밀려나면
                // 편집·보관·휴지통에 닿으려고 다시 스크롤해야 한다.
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(max = 360.dp)
                    .verticalScroll(rememberScrollState()),
            )

            if (note.tags.isNotEmpty()) {
                Row(
                    modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    // 뷰어의 태그는 **읽기 전용**이다. 편집기의 InputChip 과 달리
                    // 눌러도 떨어지지 않는다.
                    note.tags.forEach { tag ->
                        SuggestionChip(onClick = {}, enabled = false, label = { Text("#${tag.name}") })
                    }
                }
            }

            if (note.attachments.isNotEmpty()) {
                Row(
                    modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    note.attachments.forEach { attachment ->
                        // 지우기 손잡이를 주지 않는다 — 뷰어에서 사라지는 것은 없어야 한다.
                        AttachmentThumbnail(attachment = attachment, urlCache = urlCache)
                    }
                }
            }

            HorizontalDivider()

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                // 편집은 **한 번 더** 눌러야 들어간다. 이 한 번이 BRU-66의 재발을 막는다.
                AssistChip(onClick = onEdit, label = { Text("편집") })
                if (viewMode == NoteViewMode.ACTIVE) {
                    AssistChip(onClick = onArchive, label = { Text("보관") })
                }
                AssistChip(onClick = onTrash, label = { Text("휴지통") })
                TextButton(onClick = onDismiss, modifier = Modifier.weight(1f)) { Text("닫기") }
            }
        }
    }
}
