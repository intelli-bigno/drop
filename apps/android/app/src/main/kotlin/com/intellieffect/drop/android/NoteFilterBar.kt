package com.intellieffect.drop.android

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material3.FilterChip
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.intellieffect.drop.core.NoteCategory
import com.intellieffect.drop.core.NoteViewMode
import com.intellieffect.drop.core.NotesState
import com.intellieffect.drop.core.Tag

/**
 * 뷰모드 · 카테고리 · 태그 필터 (iOS `NoteFilterBar`와 같은 자리).
 *
 * 태그 칩 줄은 가로로 스크롤한다 — 태그가 늘어나도 줄이 늘어나 목록을 밀어내지 않게.
 */
@Composable
fun NoteFilterBar(
    state: NotesState,
    onViewMode: (NoteViewMode) -> Unit,
    onCategory: (NoteCategory) -> Unit,
    onTag: (String?) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(4.dp)) {
        SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth().padding(horizontal = 12.dp)) {
            NoteViewMode.entries.forEachIndexed { index, mode ->
                SegmentedButton(
                    selected = state.viewMode == mode,
                    onClick = { onViewMode(mode) },
                    shape = SegmentedButtonDefaults.itemShape(index, NoteViewMode.entries.size),
                ) { Text(mode.label) }
            }
        }

        Row(
            modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState())
                .padding(horizontal = 12.dp),
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            NoteCategory.entries.forEach { category ->
                FilterChip(
                    selected = state.category == category,
                    onClick = { onCategory(category) },
                    label = { Text(category.label) },
                )
            }
        }

        if (state.availableTags.isNotEmpty()) {
            Row(
                modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState())
                    .padding(horizontal = 12.dp),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                state.availableTags.sortedBy(Tag::name).forEach { tag ->
                    val selected = state.selectedTagId == tag.id
                    FilterChip(
                        selected = selected,
                        // 같은 칩을 다시 누르면 필터가 풀려야 한다 — 안 그러면
                        // 태그를 고른 뒤 전체 목록으로 돌아갈 방법이 없다.
                        onClick = { onTag(if (selected) null else tag.id) },
                        label = { Text("#${tag.name}") },
                    )
                }
            }
        }
    }
}

private val NoteViewMode.label: String
    get() = when (this) {
        NoteViewMode.ACTIVE -> "노트"
        NoteViewMode.ARCHIVED -> "보관"
        NoteViewMode.TRASH -> "휴지통"
    }

private val NoteCategory.label: String
    get() = when (this) {
        NoteCategory.ALL -> "전체"
        NoteCategory.LINKS -> "링크"
        NoteCategory.MEDIA -> "미디어"
        NoteCategory.FILES -> "파일"
    }
