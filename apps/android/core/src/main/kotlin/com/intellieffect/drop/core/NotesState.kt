package com.intellieffect.drop.core

/**
 * 홈 화면이 보는 상태 전부. iOS `NotesStore`의 프로퍼티들을 한 덩어리로 모은 것 —
 * Compose가 하나의 StateFlow만 구독하면 되도록.
 *
 * 목록은 보관·휴지통까지 통째로 들고 있고 화면에서 거른다. Flutter·iOS와 같은 구조라
 * 세 앱의 목록이 어긋나지 않는다.
 */
data class NotesState(
    val allNotes: List<Note> = emptyList(),
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
    val viewMode: NoteViewMode = NoteViewMode.ACTIVE,
    val category: NoteCategory = NoteCategory.ALL,
    val selectedTagId: String? = null,
    val searchText: String = "",
    val selectedIds: Set<String> = emptySet(),
) {
    val isSelecting: Boolean get() = selectedIds.isNotEmpty()

    val visibleNotes: List<Note>
        get() = allNotes.filter { note ->
            if (!note.matches(viewMode) || !note.matches(category)) return@filter false
            if (selectedTagId != null && note.tags.none { it.id == selectedTagId }) return@filter false
            val query = searchText.trim()
            if (query.isNotEmpty() && !note.content.contains(query, ignoreCase = true)) {
                return@filter false
            }
            true
        }

    /** 지금 목록에 실제로 붙어 있는 태그 (필터 칩용). */
    val availableTags: List<Tag>
        get() = allNotes.flatMap { it.tags }.distinctBy { it.id }
}
