package com.intellieffect.drop.android

import android.app.Activity
import android.app.Application
import android.net.Uri
import android.provider.OpenableColumns
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.intellieffect.drop.core.AttachmentType
import com.intellieffect.drop.core.AuthStore
import com.intellieffect.drop.core.GoogleIdentity
import com.intellieffect.drop.core.GoogleIdentityProvider
import com.intellieffect.drop.core.NotesStore
import kotlinx.coroutines.launch

/**
 * 화면 회전을 넘어 사는 상태. 여기 있어야 하는 이유:
 * Activity마다 새로 만들면 회전할 때 목록이 다시 불려 오고 로그인 화면이 깜빡인다.
 */
class DropViewModel(application: Application) : AndroidViewModel(application) {
    private val container = (application as DropApplication).container

    /**
     * 계정 선택 창은 Activity가 있어야 띄울 수 있는데, ViewModel은 Activity를 들고
     * 있으면 안 된다(누수). 그래서 창을 띄우는 순간에만 현재 Activity를 빌린다.
     */
    private val identityProvider = object : GoogleIdentityProvider {
        var host: Activity? = null

        override suspend fun signIn(): GoogleIdentity? {
            val activity = host ?: return null
            return CredentialManagerIdentityProvider(
                activityContext = activity,
                serverClientId = container.configuration.googleWebClientId,
            ).signIn()
        }

        override fun signOut() = Unit
    }

    val authStore = AuthStore(gateway = container.authGateway, identityProvider = identityProvider)
    val notesStore = NotesStore(container.notesRepository)
    val signedUrlCache = container.signedUrlCache

    fun attach(activity: Activity) {
        identityProvider.host = activity
    }

    fun detach() {
        identityProvider.host = null
    }

    fun signOut() = viewModelScope.launch {
        authStore.signOut()
        // 서명 URL은 사용자마다 다르다 — 비우지 않으면 다음 사용자가 앞 사용자의
        // 파일 URL을 그대로 쓰게 된다.
        signedUrlCache.clear()
    }

    // MARK: - 태그

    fun addTag(noteId: String, name: String) = withNotesReload {
        container.tagsRepository.addTag(name, noteId)
    }

    fun removeTag(noteId: String, tagId: String) = withNotesReload {
        container.tagsRepository.removeTag(tagId, noteId)
    }

    // MARK: - 첨부

    fun addAttachment(noteId: String, uri: Uri, type: AttachmentType) = withNotesReload {
        val resolver = getApplication<Application>().contentResolver
        val bytes = resolver.openInputStream(uri)?.use { it.readBytes() }
            ?: error("파일을 읽지 못했습니다")
        container.attachmentsRepository.upload(
            bytes = bytes,
            fileName = uri.displayName(getApplication()) ?: "attachment",
            type = type,
            noteId = noteId,
        )
        // 카테고리 필터(미디어)가 맞아떨어지도록 플래그도 갱신한다 —
        // 안 하면 첨부는 붙었는데 "미디어" 탭에서 보이지 않는다.
        container.notesRepository.updateCategories(
            id = noteId,
            hasLink = false,
            hasMedia = true,
            hasFiles = false,
        )
    }

    fun removeAttachment(attachment: com.intellieffect.drop.core.Attachment) = withNotesReload {
        container.attachmentsRepository.delete(attachment)
    }

    /**
     * 태그·첨부는 노트 목록에 함께 실려 오므로, 바꾼 뒤 목록을 다시 읽어야 화면이 맞다.
     * 실패는 목록 상태의 오류 자리에 그대로 얹는다 (화면이 이미 그것을 보여 준다).
     */
    private fun withNotesReload(work: suspend () -> Unit) = viewModelScope.launch {
        try {
            work()
            notesStore.load()
        } catch (error: Throwable) {
            if (error is kotlinx.coroutines.CancellationException) throw error
            notesStore.report(error)
        }
    }
}

/** 공유·선택으로 들어온 URI의 표시 이름. 확장자를 얻는 데 쓴다. */
fun Uri.displayName(application: Application): String? = runCatching {
    application.contentResolver.query(this, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
        ?.use { cursor -> if (cursor.moveToFirst()) cursor.getString(0) else null }
}.getOrNull() ?: lastPathSegment
