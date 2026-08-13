package com.intellieffect.drop.core

/** 리포지토리가 화면에 알려 주는 실패 종류. 문구는 [NotesStore]가 붙인다. */
sealed class NotesRepositoryException(message: String) : Exception(message) {
    data object NotAuthenticated : NotesRepositoryException("not authenticated") {
        private fun readResolve(): Any = NotAuthenticated
    }

    class Network(val reason: String) : NotesRepositoryException(reason)
    class Decoding(val reason: String) : NotesRepositoryException(reason)
    class Rejected(val reason: String) : NotesRepositoryException(reason)
}

/**
 * 노트 데이터 접근 경계. 화면은 이 인터페이스만 알고, 테스트는 인메모리 구현을 쓴다.
 * (iOS `NotesRepository` 프로토콜과 같은 계약)
 */
interface NotesRepository {
    /**
     * 목록 전체를 한 번에 가져온다. 보관·휴지통까지 포함해 받고 화면에서 거른다 —
     * Flutter·iOS 앱과 같은 방식이라 세 앱의 목록이 어긋나지 않는다.
     */
    suspend fun loadNotes(): List<Note>

    suspend fun createNote(content: String, parentId: String? = null): Note
    suspend fun updateNote(id: String, content: String)

    /** 휴지통으로 보낸다(soft delete). 보관 상태였다면 함께 해제한다. */
    suspend fun moveToTrash(id: String)
    suspend fun restoreFromTrash(id: String)
    suspend fun archive(id: String)
    suspend fun unarchive(id: String)
    suspend fun deletePermanently(id: String)
    suspend fun emptyTrash()

    suspend fun setPinned(id: String, isPinned: Boolean)
    suspend fun setLocked(id: String, isLocked: Boolean)
    suspend fun setPriority(id: String, priority: Int)
    suspend fun updateCategories(id: String, hasLink: Boolean, hasMedia: Boolean, hasFiles: Boolean)
}
