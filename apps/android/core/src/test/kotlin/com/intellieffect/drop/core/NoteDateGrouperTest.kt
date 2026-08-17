package com.intellieffect.drop.core

import java.time.Instant
import java.time.ZoneId
import kotlin.test.Test
import kotlin.test.assertEquals

/** iOS `NoteDateGrouperTests` · `RelativeTimeFormatter` 검증의 이식본. */
class NoteDateGrouperTest {
    private val zone: ZoneId = ZoneId.of("Asia/Seoul")

    /** 2026-08-17 15:00 KST */
    private val now: Instant = Instant.parse("2026-08-17T06:00:00Z")

    private val grouper = NoteDateGrouper(zone)

    private fun note(id: String, createdAt: Instant, pinned: Boolean = false) = Note(
        id = id,
        displayId = 1,
        content = id,
        createdAt = createdAt,
        updatedAt = createdAt,
        source = NoteSource.MOBILE,
        isPinned = pinned,
        pinnedAt = if (pinned) createdAt else null,
    )

    @Test
    fun `오늘 어제 그리고 며칠 전으로 묶는다`() {
        val sections = grouper.sections(
            listOf(
                note("오늘", now.minusSeconds(3600)),
                note("어제", now.minusSeconds(30 * 3600)),
                note("사흘전", now.minusSeconds(3 * 24 * 3600)),
            ),
            now,
        )

        assertEquals(listOf("오늘", "어제", "3일 전"), sections.map { it.title })
        assertEquals(listOf("오늘"), sections[0].notes.map { it.id })
    }

    /** 3개월 전에 만든 고정 노트가 "오늘" 아래 들어가면 안 된다. */
    @Test
    fun `고정 노트는 날짜와 섞이지 않고 따로 모인다`() {
        val sections = grouper.sections(
            listOf(
                note("고정", now.minusSeconds(90L * 24 * 3600), pinned = true),
                note("오늘", now),
            ),
            now,
        )

        assertEquals("고정", sections.first().title)
        assertEquals(listOf("고정"), sections.first().notes.map { it.id })
        assertEquals("오늘", sections[1].title)
    }

    /** 같은 날 노트는 한 섹션에 모이고, 입력 순서가 유지된다. */
    @Test
    fun `같은 날은 한 섹션이고 순서를 바꾸지 않는다`() {
        val sections = grouper.sections(
            listOf(note("a", now), note("b", now.minusSeconds(60)), note("c", now.minusSeconds(120))),
            now,
        )

        assertEquals(1, sections.size)
        assertEquals(listOf("a", "b", "c"), sections.single().notes.map { it.id })
    }

    /** 기기 시계가 앞서 있어도 "미래" 섹션이 생기면 안 된다. */
    @Test
    fun `미래 시각은 오늘로 접는다`() {
        val sections = grouper.sections(listOf(note("미래", now.plusSeconds(7200))), now)

        assertEquals(listOf("오늘"), sections.map { it.title })
    }

    /**
     * 시간대 경계: KST 00:30에 만든 노트는 UTC로는 전날이다.
     * UTC로 묶으면 "어제"로 잘못 뜬다.
     */
    @Test
    fun `자정 직후 노트도 오늘로 묶인다`() {
        val justAfterMidnightKst = Instant.parse("2026-08-16T15:30:00Z") // 2026-08-17 00:30 KST

        val sections = grouper.sections(listOf(note("자정직후", justAfterMidnightKst)), now)

        assertEquals(listOf("오늘"), sections.map { it.title })
    }

    @Test
    fun `빈 목록은 섹션도 없다`() {
        assertEquals(emptyList(), grouper.sections(emptyList(), now))
    }
}

class RelativeTimeFormatterTest {
    private val zone: ZoneId = ZoneId.of("Asia/Seoul")
    private val now: Instant = Instant.parse("2026-08-17T06:00:00Z") // 15:00 KST
    private val formatter = RelativeTimeFormatter(zone)

    @Test
    fun `1분 안쪽은 초로 센다`() {
        assertEquals("0초전", formatter.format(now, now))
        assertEquals("42초전", formatter.format(now.minusSeconds(42), now))
    }

    @Test
    fun `1시간 안쪽은 분으로 센다`() {
        assertEquals("1분전", formatter.format(now.minusSeconds(60), now))
        assertEquals("59분전", formatter.format(now.minusSeconds(59 * 60), now))
    }

    @Test
    fun `오늘과 어제는 시각을 붙인다`() {
        assertEquals("오늘 12:00", formatter.format(now.minusSeconds(3 * 3600), now))
        assertEquals("어제 09:00", formatter.format(Instant.parse("2026-08-16T00:00:00Z"), now))
    }

    @Test
    fun `그보다 오래된 것은 날짜로 적는다`() {
        assertEquals("2026. 8. 10.", formatter.format(Instant.parse("2026-08-10T02:00:00Z"), now))
    }

    /** 기기 시계가 앞서 있으면 음수 경과가 나온다 — 0초전으로 접는다. */
    @Test
    fun `미래 시각은 0초전이다`() {
        assertEquals("0초전", formatter.format(now.plusSeconds(600), now))
    }
}
