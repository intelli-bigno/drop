package com.intellieffect.drop.core

import java.io.File
import java.nio.file.Files
import java.time.Instant
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/** iOS `WidgetSnapshotTests`에 대응한다. 위젯이 무엇을 보여줄지 고르고 자르는 규칙. */
class WidgetSnapshotTest {
    private val now: Instant = Instant.ofEpochSecond(1_800_000_000)

    private fun note(
        id: String,
        content: String = "내용",
        offsetSeconds: Long = 0,
        archived: Boolean = false,
        trashed: Boolean = false,
    ) = Note(
        id = id,
        displayId = 1,
        content = content,
        createdAt = now.plusSeconds(offsetSeconds),
        updatedAt = now,
        source = NoteSource.MOBILE,
        archivedAt = if (archived) now else null,
        deletedAt = if (trashed) now else null,
    )

    @Test
    fun `최신 노트 세 개만 담는다`() {
        val snapshot = WidgetSnapshot.from(
            (1..5).map { note("n$it", offsetSeconds = it.toLong()) },
            generatedAt = now,
        )

        assertEquals(listOf("n5", "n4", "n3"), snapshot.notes.map { it.id })
    }

    /** 보관·휴지통 노트가 위젯에 뜨면 지운 줄 알았던 것이 계속 보인다. */
    @Test
    fun `보관과 휴지통 노트는 담지 않는다`() {
        val snapshot = WidgetSnapshot.from(
            listOf(
                note("활성", offsetSeconds = 3),
                note("보관", offsetSeconds = 2, archived = true),
                note("휴지통", offsetSeconds = 1, trashed = true),
            ),
            generatedAt = now,
        )

        assertEquals(listOf("활성"), snapshot.notes.map { it.id })
    }

    @Test
    fun `여러 줄 본문은 한 줄로 접는다`() {
        val snapshot = WidgetSnapshot.from(
            listOf(note("n1", content = "첫 줄\n\n  둘째   줄\t셋째")),
            generatedAt = now,
        )

        assertEquals("첫 줄 둘째 줄 셋째", snapshot.notes.single().excerpt)
    }

    @Test
    fun `긴 본문은 말줄임표로 자른다`() {
        val long = "가".repeat(200)

        val excerpt = WidgetSnapshot.excerpt(long)

        assertEquals(WidgetSnapshot.EXCERPT_LIMIT, excerpt.length)
        assertTrue(excerpt.endsWith("…"))
    }

    /** 사진만 붙인 노트는 본문이 비어 있다 — 위젯에 빈 줄이 뜨면 안 된다. */
    @Test
    fun `빈 본문은 대체 문구로 채운다`() {
        assertEquals(WidgetSnapshot.EMPTY_CONTENT_PLACEHOLDER, WidgetSnapshot.excerpt("   \n "))
    }

    @Test
    fun `노트가 없으면 빈 스냅샷이다`() {
        assertTrue(WidgetSnapshot.from(emptyList(), generatedAt = now).isEmpty)
    }
}

class WidgetSnapshotStoreTest {
    private val directory: File = Files.createTempDirectory("drop-widget").toFile()
    private val file = File(directory, "widget-snapshot.json")
    private val store = WidgetSnapshotStore(file)

    private val snapshot = WidgetSnapshot(
        notes = listOf(
            WidgetNote(id = "n1", excerpt = "장보기: 우유, 계란", createdAt = Instant.ofEpochSecond(1_800_000_000)),
        ),
        generatedAt = Instant.ofEpochSecond(1_800_000_100),
    )

    @Test
    fun `쓴 것을 그대로 읽는다`() {
        store.write(snapshot)

        assertEquals(snapshot, store.read())
    }

    /** 위젯은 앱이 한 번도 실행되지 않은 상태에서도 그려져야 한다. */
    @Test
    fun `파일이 없으면 빈 스냅샷이다`() {
        assertEquals(WidgetSnapshot.EMPTY, WidgetSnapshotStore(File(directory, "없는파일.json")).read())
    }

    /** 쓰는 중에 프로세스가 죽으면 잘린 JSON이 남는다. 위젯이 그것 때문에 죽어서는 안 된다. */
    @Test
    fun `깨진 파일은 빈 스냅샷으로 읽는다`() {
        file.writeText("{\"notes\": [{\"id\":")

        assertEquals(WidgetSnapshot.EMPTY, store.read())
    }

    @Test
    fun `다시 쓰면 덮어쓴다`() {
        store.write(snapshot)
        store.write(WidgetSnapshot.EMPTY)

        assertTrue(store.read().isEmpty)
    }
}
