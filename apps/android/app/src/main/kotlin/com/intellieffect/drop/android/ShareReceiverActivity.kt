package com.intellieffect.drop.android

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Parcelable
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.lifecycle.lifecycleScope
import com.intellieffect.drop.core.AttachmentType
import com.intellieffect.drop.core.NotesRepositoryException
import com.intellieffect.drop.core.SharedCapture
import kotlinx.coroutines.launch

/**
 * 다른 앱의 "공유"에서 DROP을 고르면 여기로 온다 (iOS `DropShare` 대응).
 *
 * 화면을 띄우지 않는다 — 퀵캡처의 값은 공유 → 담김까지 탭이 한 번도 더 들지 않는 것이다.
 * 결과는 토스트로만 알린다. 무엇을 어떤 순서로 저장할지는 `core`의 [SharedCapture]가 정한다.
 */
class ShareReceiverActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val container = (application as DropApplication).container

        lifecycleScope.launch {
            val message = runCatching { capture(container) }.fold(
                onSuccess = { note -> if (note != null) "DROP에 담았습니다" else "담을 내용이 없습니다" },
                onFailure = { error -> failureMessage(error) },
            )
            Toast.makeText(this@ShareReceiverActivity, message, Toast.LENGTH_LONG).show()
            finish()
        }
    }

    private suspend fun capture(container: DropContainer): com.intellieffect.drop.core.Note? {
        // 공유는 앱을 켜지 않고 들어오는 경로다 — 저장된 세션을 여기서 먼저 살려 낸다.
        // 빠뜨리면 로그인해 둔 사용자에게도 "먼저 로그인해 주세요"가 뜬다.
        container.authGateway.restore()

        return SharedCapture(
            notes = container.notesRepository,
            attachments = container.attachmentsRepository,
        ).capture(payload())
    }

    /**
     * 파일 바이트를 **노트를 만들기 전에** 다 읽는다. 읽지 못하면 그 자리에서 실패시킨다 —
     * 조용히 건너뛰면 "담았습니다"라고 알리면서 첨부 없는 노트만 남는다 (실기에서 겪었다).
     */
    private fun payload(): SharedCapture.Payload {
        val streams = intent.streams()
        return SharedCapture.Payload(
            text = intent.getStringExtra(Intent.EXTRA_TEXT),
            subject = intent.getStringExtra(Intent.EXTRA_SUBJECT),
            files = streams.map { uri ->
                val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
                    ?: throw NotesRepositoryException.Rejected("공유된 파일을 읽지 못했습니다")
                SharedCapture.SharedFile(
                    name = uri.displayName(application) ?: "shared",
                    type = attachmentType(uri),
                    bytes = bytes,
                )
            },
        )
    }

    private fun failureMessage(error: Throwable): String = when (error) {
        is NotesRepositoryException.NotAuthenticated -> "DROP에 먼저 로그인해 주세요"
        is NotesRepositoryException.Rejected -> "담지 못했습니다: ${error.reason}"
        is NotesRepositoryException.Network -> "네트워크에 연결하지 못했습니다"
        else -> "담지 못했습니다: ${error.message ?: error}"
    }

    private fun Intent.streams(): List<Uri> = when (action) {
        Intent.ACTION_SEND -> listOfNotNull(parcelable<Uri>(Intent.EXTRA_STREAM))
        Intent.ACTION_SEND_MULTIPLE -> parcelableList<Uri>(Intent.EXTRA_STREAM).orEmpty()
        else -> emptyList()
    }

    private fun attachmentType(uri: Uri): AttachmentType =
        when (contentResolver.getType(uri)?.substringBefore('/')) {
            "image" -> AttachmentType.IMAGE
            "video" -> AttachmentType.VIDEO
            "audio" -> AttachmentType.AUDIO
            else -> AttachmentType.FILE
        }

    @Suppress("DEPRECATION")
    private inline fun <reified T : Parcelable> Intent.parcelable(name: String): T? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            getParcelableExtra(name, T::class.java)
        } else {
            getParcelableExtra(name) as? T
        }

    @Suppress("DEPRECATION")
    private inline fun <reified T : Parcelable> Intent.parcelableList(name: String): List<T>? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            getParcelableArrayListExtra(name, T::class.java)
        } else {
            getParcelableArrayListExtra(name)
        }
}
