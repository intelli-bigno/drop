package com.intellieffect.drop.android

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import coil3.compose.AsyncImage
import com.intellieffect.drop.core.Attachment
import com.intellieffect.drop.core.AttachmentType
import com.intellieffect.drop.core.SignedUrlCache

/**
 * 첨부 썸네일. 비공개 버킷이라 서명 URL이 필요하고, 그 발급은 [SignedUrlCache]가
 * 같은 파일에 대해 한 번만 하도록 막는다.
 *
 * [onRemove]가 없으면 지우기 손잡이를 그리지 않는다 — 읽기 전용 화면(뷰어)에서
 * 무언가가 사라질 수 있으면 안 된다.
 */
@Composable
fun AttachmentThumbnail(
    attachment: Attachment,
    urlCache: SignedUrlCache,
    modifier: Modifier = Modifier,
    onRemove: (() -> Unit)? = null,
) {
    val url by produceState<String?>(initialValue = null, attachment.id) {
        value = runCatching { urlCache.url(attachment.storagePath) }.getOrNull()
    }

    Box(
        modifier = modifier.size(72.dp).clip(RoundedCornerShape(8.dp)),
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

        if (onRemove != null) {
            TextButton(onClick = onRemove, modifier = Modifier.align(Alignment.TopEnd)) { Text("×") }
        }
    }
}
