package com.intellieffect.drop.android

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.InputChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.unit.dp
import coil3.compose.AsyncImage
import com.intellieffect.drop.core.Attachment
import com.intellieffect.drop.core.AttachmentType
import com.intellieffect.drop.core.Note
import com.intellieffect.drop.core.SignedUrlCache

/**
 * 이미 저장된 노트를 여는 시트 — 본문 · 태그 · 첨부를 한 자리에서 다룬다.
 *
 * 새 노트는 [NoteComposerSheet]를 쓴다. 태그·첨부는 `note_id`가 있어야 붙으므로
 * 노트가 저장된 뒤에만 편집할 수 있다.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NoteEditorSheet(
    note: Note,
    urlCache: SignedUrlCache,
    onDismiss: () -> Unit,
    onSave: (String) -> Unit,
    onAddTag: (String) -> Unit,
    onRemoveTag: (String) -> Unit,
    onAddAttachment: (uri: android.net.Uri, type: AttachmentType) -> Unit,
    onRemoveAttachment: (Attachment) -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var value by remember(note.id) {
        mutableStateOf(TextFieldValue(note.content, selection = TextRange(note.content.length)))
    }
    var tagDraft by remember(note.id) { mutableStateOf("") }

    val pickMedia = rememberLauncherForActivityResult(
        ActivityResultContracts.PickVisualMedia(),
    ) { uri ->
        // 취소하면 uri가 null이다 — 오류가 아니다.
        uri?.let { onAddAttachment(it, AttachmentType.IMAGE) }
    }
    val pickVideo = rememberLauncherForActivityResult(
        ActivityResultContracts.PickVisualMedia(),
    ) { uri ->
        uri?.let { onAddAttachment(it, AttachmentType.VIDEO) }
    }

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState) {
        Column(
            modifier = Modifier.fillMaxWidth().padding(16.dp).imePadding(),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            OutlinedTextField(
                value = value,
                onValueChange = { value = it },
                modifier = Modifier.fillMaxWidth(),
                minLines = 3,
            )

            // 태그 — 칩의 × 로 떼고, 아래 입력줄로 붙인다.
            Row(
                modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                note.tags.forEach { tag ->
                    InputChip(
                        selected = false,
                        onClick = { onRemoveTag(tag.id) },
                        label = { Text("#${tag.name} ×") },
                    )
                }
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                OutlinedTextField(
                    value = tagDraft,
                    onValueChange = { tagDraft = it },
                    modifier = Modifier.weight(1f),
                    placeholder = { Text("태그 추가") },
                    singleLine = true,
                )
                TextButton(
                    enabled = tagDraft.isNotBlank(),
                    onClick = {
                        onAddTag(tagDraft)
                        tagDraft = ""
                    },
                ) { Text("붙이기") }
            }

            if (note.attachments.isNotEmpty()) {
                Row(
                    modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    note.attachments.forEach { attachment ->
                        AttachmentThumbnail(
                            attachment = attachment,
                            urlCache = urlCache,
                            onRemove = { onRemoveAttachment(attachment) },
                        )
                    }
                }
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                AssistChip(
                    onClick = {
                        pickMedia.launch(
                            PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly),
                        )
                    },
                    label = { Text("사진") },
                )
                AssistChip(
                    onClick = {
                        pickVideo.launch(
                            PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.VideoOnly),
                        )
                    },
                    label = { Text("영상") },
                )
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.End),
            ) {
                TextButton(onClick = onDismiss) { Text("닫기") }
                Button(
                    // 본문을 다듬지 않는다 — 저장값은 입력한 그대로 (원문 보존).
                    enabled = value.text != note.content,
                    onClick = { onSave(value.text) },
                ) { Text("저장") }
            }
        }
    }
}

/**
 * 첨부 썸네일. 비공개 버킷이라 서명 URL이 필요하고, 그 발급은 [SignedUrlCache]가
 * 같은 파일에 대해 한 번만 하도록 막는다.
 */
@Composable
private fun AttachmentThumbnail(
    attachment: Attachment,
    urlCache: SignedUrlCache,
    onRemove: () -> Unit,
) {
    val url by produceState<String?>(initialValue = null, attachment.id) {
        value = runCatching { urlCache.url(attachment.storagePath) }.getOrNull()
    }

    Box(
        modifier = Modifier.size(72.dp).clip(RoundedCornerShape(8.dp)),
        contentAlignment = Alignment.Center,
    ) {
        when {
            attachment.isImage && url != null -> AsyncImage(
                model = url,
                contentDescription = attachment.filename,
                contentScale = ContentScale.Crop,
                modifier = Modifier.size(72.dp),
            )

            url == null && attachment.isImage -> CircularProgressIndicator(Modifier.size(20.dp))

            // 이미지가 아닌 첨부는 아이콘 대신 종류를 글자로 보여 준다 —
            // 목록에서 무엇이 붙어 있는지 알 수 있으면 충분하다.
            else -> Text(
                text = when (attachment.type) {
                    AttachmentType.VIDEO -> "🎬"
                    AttachmentType.AUDIO -> "🎧"
                    AttachmentType.INSTAGRAM, AttachmentType.YOUTUBE -> "🔗"
                    else -> "📄"
                },
                style = MaterialTheme.typography.titleLarge,
            )
        }

        TextButton(onClick = onRemove, modifier = Modifier.align(Alignment.TopEnd)) { Text("×") }
    }
}
