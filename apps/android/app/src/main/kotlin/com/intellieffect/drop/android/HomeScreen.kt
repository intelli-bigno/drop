package com.intellieffect.drop.android

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.intellieffect.drop.core.Attachment
import com.intellieffect.drop.core.AttachmentType
import com.intellieffect.drop.core.Note
import com.intellieffect.drop.core.NoteDateGrouper
import com.intellieffect.drop.core.NoteViewMode
import com.intellieffect.drop.core.NotesStore
import com.intellieffect.drop.core.SignedUrlCache
import kotlinx.coroutines.launch

/**
 * 홈 화면 (iOS `HomeView`와 같은 자리).
 *
 * 목록은 `NotesStore`가 들고 있는 것을 그대로 그린다 — 필터·검색·선택은 전부
 * `core`의 상태에서 계산되므로, 이 파일에는 조립과 손짓만 남는다.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    store: NotesStore,
    userEmail: String?,
    urlCache: SignedUrlCache,
    onSignOut: () -> Unit,
    onAddTag: (noteId: String, name: String) -> Unit,
    onRemoveTag: (noteId: String, tagId: String) -> Unit,
    onAddAttachment: (noteId: String, uri: android.net.Uri, type: AttachmentType) -> Unit,
    onRemoveAttachment: (Attachment) -> Unit,
    /** 위젯의 ＋ 로 들어왔으면 목록보다 작성 시트를 먼저 띄운다. */
    startComposer: Boolean = false,
    modifier: Modifier = Modifier,
) {
    val state by store.state.collectAsStateWithLifecycle()
    val scope = rememberCoroutineScope()
    val snackbarHost = remember { SnackbarHostState() }
    val grouper = remember { NoteDateGrouper() }

    var isSearching by remember { mutableStateOf(false) }
    var composing by remember {
        mutableStateOf<ComposerTarget?>(if (startComposer) ComposerTarget.New else null)
    }

    // 오류는 한 번 띄우고 지운다. 남겨 두면 다음 동작마다 같은 스낵바가 다시 뜬다.
    LaunchedEffect(state.errorMessage) {
        val message = state.errorMessage ?: return@LaunchedEffect
        snackbarHost.showSnackbar(message)
        store.dismissError()
    }

    Scaffold(
        modifier = modifier.fillMaxSize(),
        snackbarHost = { SnackbarHost(snackbarHost) },
        topBar = {
            if (state.isSelecting) {
                SelectionTopBar(
                    count = state.selectedIds.size,
                    viewMode = state.viewMode,
                    onCancel = store::clearSelection,
                    onTrash = { scope.launch { store.trashSelected() } },
                    onDeleteForever = { scope.launch { store.deleteSelectedPermanently() } },
                )
            } else {
                TopAppBar(
                    title = { Text(userEmail ?: "DROP", style = MaterialTheme.typography.titleMedium) },
                    actions = {
                        TextButton(onClick = { isSearching = !isSearching }) { Text("검색") }
                        TextButton(onClick = onSignOut) { Text("로그아웃") }
                    },
                )
            }
        },
        floatingActionButton = {
            if (state.viewMode == NoteViewMode.ACTIVE && !state.isSelecting) {
                FloatingActionButton(
                    onClick = { composing = ComposerTarget.New },
                    // M3 기본값(primaryContainer)은 이 팔레트에서 종이와 거의 구별되지
                    // 않는다. 담기는 이 앱의 유일한 주 동작이라 강조색을 그대로 쓴다.
                    containerColor = MaterialTheme.colorScheme.primary,
                    contentColor = MaterialTheme.colorScheme.onPrimary,
                ) { Text("＋") }
            }
        },
    ) { insets ->
        Column(Modifier.padding(insets).fillMaxSize()) {
            if (isSearching) {
                OutlinedTextField(
                    value = state.searchText,
                    onValueChange = store::setSearchText,
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 4.dp),
                    placeholder = { Text("노트 검색") },
                    singleLine = true,
                )
            }

            NoteFilterBar(
                state = state,
                onViewMode = store::setViewMode,
                onCategory = store::setCategory,
                onTag = store::setSelectedTagId,
            )

            PullToRefreshBox(
                isRefreshing = state.isLoading,
                // 손을 떼면 요청이 취소된다 — 취소는 오류가 아니므로 목록도 문구도
                // 건드리지 않는다 (NotesStore가 이미 그렇게 다룬다, iOS BRU-32).
                onRefresh = { scope.launch { store.load() } },
                modifier = Modifier.fillMaxSize(),
            ) {
                val sections = grouper.sections(state.visibleNotes)

                // 목록이 비어도 **같은 스크롤 컨테이너**를 그린다. 빈 화면을 스크롤되지 않는
                // Box로 바꾸면 당겨서 새로고침이 동작하지 않는다 — 노트가 하나도 없을 때가
                // 정확히 새로고침이 가장 필요한 순간이다 (iOS에서 같은 사고가 있었다, #40).
                LazyColumn(Modifier.fillMaxSize()) {
                    if (sections.isEmpty()) {
                        item("empty") {
                            EmptyNotes(
                                viewMode = state.viewMode,
                                hasQuery = state.searchText.isNotBlank(),
                                isLoading = state.isLoading,
                                // 화면 전체를 차지해야 빈 목록에서도 당길 수 있다.
                                modifier = Modifier.fillParentMaxSize(),
                            )
                        }
                    }

                    sections.forEach { section ->
                            item(key = "header-${section.id}") {
                                Text(
                                    text = section.title,
                                    style = MaterialTheme.typography.labelLarge,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    modifier = Modifier.fillMaxWidth()
                                        .padding(start = 16.dp, top = 16.dp, bottom = 4.dp),
                                )
                            }

                            items(section.notes, key = { it.id }) { note ->
                                SwipeableNoteRow(
                                    note = note,
                                    viewMode = state.viewMode,
                                    isSelected = note.id in state.selectedIds,
                                    onClick = {
                                        if (state.isSelecting) {
                                            store.toggleSelection(note.id)
                                        } else {
                                            composing = ComposerTarget.Edit(note)
                                        }
                                    },
                                    onLongClick = { store.toggleSelection(note.id) },
                                    onSwipeStart = { scope.launch { store.swipeStart(note) } },
                                    onSwipeEnd = { scope.launch { store.swipeEnd(note) } },
                                )
                                HorizontalDivider()
                            }
                    }
                }
            }
        }
    }

    when (val target = composing) {
        null -> Unit

        ComposerTarget.New -> NoteComposerSheet(
            initialContent = "",
            onDismiss = { composing = null },
            onSubmit = { content ->
                composing = null
                scope.launch { store.create(content) }
            },
        )

        is ComposerTarget.Edit -> {
            // 목록의 최신 노트를 다시 찾아 쓴다. 태그·첨부를 고치면 목록이 다시 불려 오는데,
            // 열 때 복사해 둔 값을 그대로 쓰면 시트만 옛 상태로 남는다.
            val live = state.allNotes.firstOrNull { it.id == target.note.id }
            if (live == null) {
                composing = null
            } else {
                NoteEditorSheet(
                    note = live,
                    urlCache = urlCache,
                    onDismiss = { composing = null },
                    onSave = { content ->
                        composing = null
                        scope.launch { store.update(live.id, content) }
                    },
                    onAddTag = { name -> onAddTag(live.id, name) },
                    onRemoveTag = { tagId -> onRemoveTag(live.id, tagId) },
                    onAddAttachment = { uri, type -> onAddAttachment(live.id, uri, type) },
                    onRemoveAttachment = onRemoveAttachment,
                )
            }
        }
    }
}

private sealed interface ComposerTarget {
    data object New : ComposerTarget
    data class Edit(val note: Note) : ComposerTarget
}

/** 스와이프 동작의 뜻은 뷰모드마다 다르다 (라벨은 `NoteRow`가 같은 규칙으로 그린다). */
private suspend fun NotesStore.swipeStart(note: Note) = when (state.value.viewMode) {
    NoteViewMode.ACTIVE -> setPinned(note.id, !note.isPinned)
    NoteViewMode.ARCHIVED -> unarchive(note.id)
    NoteViewMode.TRASH -> restore(note.id)
}

private suspend fun NotesStore.swipeEnd(note: Note) = when (state.value.viewMode) {
    NoteViewMode.ACTIVE -> archive(note.id)
    NoteViewMode.ARCHIVED -> moveToTrash(note.id)
    NoteViewMode.TRASH -> deletePermanently(note.id)
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SelectionTopBar(
    count: Int,
    viewMode: NoteViewMode,
    onCancel: () -> Unit,
    onTrash: () -> Unit,
    onDeleteForever: () -> Unit,
) {
    TopAppBar(
        title = { Text("${count}개 선택") },
        navigationIcon = { TextButton(onClick = onCancel) { Text("취소") } },
        actions = {
            if (viewMode == NoteViewMode.TRASH) {
                TextButton(onClick = onDeleteForever) { Text("영구 삭제") }
            } else {
                TextButton(onClick = onTrash) { Text("휴지통") }
            }
        },
    )
}

@Composable
private fun EmptyNotes(
    viewMode: NoteViewMode,
    hasQuery: Boolean,
    isLoading: Boolean,
    modifier: Modifier = Modifier,
) {
    val message = when {
        // 불러오는 중에 "노트가 없습니다"를 띄우면 첫 실행에서 거짓말을 하게 된다.
        isLoading -> ""
        hasQuery -> "검색 결과가 없습니다"
        viewMode == NoteViewMode.ARCHIVED -> "보관한 노트가 없습니다"
        viewMode == NoteViewMode.TRASH -> "휴지통이 비어 있습니다"
        else -> "아직 노트가 없습니다\n＋ 로 첫 노트를 담아 보세요"
    }

    Box(modifier, contentAlignment = Alignment.Center) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(
                text = message,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )
        }
    }
}
