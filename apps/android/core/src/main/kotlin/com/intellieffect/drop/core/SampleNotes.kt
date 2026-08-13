package com.intellieffect.drop.core

import java.time.Instant

/**
 * 프리뷰·스캐폴드 화면용 표본. 실제 데이터는 BRU-39 이후 Supabase에서 온다.
 */
fun sampleNotes(now: Instant = Instant.now()): List<Note> = listOf(
    Note(
        id = "sample-1",
        displayId = 1,
        content = "네이티브 Android 스캐폴드가 core 목록을 그대로 그린다",
        tags = listOf(Tag(id = "dev", name = "dev", createdAt = now)),
        createdAt = now,
        updatedAt = now,
        source = NoteSource.MOBILE,
        isPinned = true,
        pinnedAt = now,
    ),
    Note(
        id = "sample-2",
        displayId = 2,
        content = "로그인·실제 Supabase 호출은 BRU-39 이후",
        createdAt = now.minusSeconds(3600),
        updatedAt = now.minusSeconds(3600),
        source = NoteSource.MOBILE,
    ),
)
