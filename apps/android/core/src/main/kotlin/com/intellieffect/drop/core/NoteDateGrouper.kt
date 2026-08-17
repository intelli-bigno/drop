package com.intellieffect.drop.core

import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.temporal.ChronoUnit

/** 목록 화면의 한 섹션. 화면은 이 목록을 그대로 그리기만 한다. */
data class NoteSection(val id: String, val title: String, val notes: List<Note>)

/**
 * 정렬된 노트 목록을 날짜 섹션으로 묶는다 (iOS `NoteDateGrouper`의 이식본).
 *
 * 순수 함수로 떼어 두어 에뮬레이터 없이 검증한다 — 자정·시간대 경계가 화면 코드 안에
 * 숨어 있으면 검증할 방법이 없다.
 */
class NoteDateGrouper(private val zone: ZoneId = ZoneId.systemDefault()) {
    /**
     * 입력 순서를 그대로 유지한다 — 정렬은 [NoteAssembler.sorted]의 몫이고,
     * 여기서 다시 정렬하면 두 규칙이 어긋날 때 화면이 조용히 달라진다.
     *
     * 고정한 노트는 날짜와 무관하게 맨 위로 뜨므로(정렬 규칙) 날짜에 섞지 않고 따로
     * 모은다. 3개월 전에 만든 고정 노트가 "오늘" 아래 들어가는 일을 막는다.
     */
    fun sections(notes: List<Note>, now: Instant = Instant.now()): List<NoteSection> {
        val sections = mutableListOf<NoteSection>()

        val pinned = notes.filter { it.isPinned }
        if (pinned.isNotEmpty()) sections += NoteSection("pinned", "고정", pinned)

        val today = LocalDate.ofInstant(now, zone)
        val byDay = LinkedHashMap<LocalDate, MutableList<Note>>()

        for (note in notes) {
            if (note.isPinned) continue
            // 미래 시각(기기 시계 어긋남)은 오늘로 접는다.
            val day = minOf(LocalDate.ofInstant(note.createdAt, zone), today)
            byDay.getOrPut(day) { mutableListOf() } += note
        }

        byDay.forEach { (day, dayNotes) ->
            sections += NoteSection(id = "day-$day", title = title(day, today), notes = dayNotes)
        }

        return sections
    }

    private fun title(day: LocalDate, today: LocalDate): String =
        when (val days = ChronoUnit.DAYS.between(day, today)) {
            0L -> "오늘"
            1L -> "어제"
            else -> "${days}일 전"
        }
}

/**
 * 노트에 붙는 상대 시간 문구 (iOS `RelativeTimeFormatter`의 이식본).
 *
 * 문구는 iOS·Flutter와 1:1로 같아야 한다 — 같은 데이터를 여러 앱이 나란히 보여 주는데
 * 표기가 갈리면 같은 노트가 다른 시각에 만들어진 것처럼 보인다.
 */
class RelativeTimeFormatter(private val zone: ZoneId = ZoneId.systemDefault()) {
    fun format(instant: Instant, now: Instant = Instant.now()): String {
        val elapsed = Duration.between(instant, now).coerceAtLeast(Duration.ZERO)

        val seconds = elapsed.seconds
        if (seconds < 60) return "${seconds}초전"

        val minutes = seconds / 60
        if (minutes < 60) return "${minutes}분전"

        val moment = LocalDateTime.ofInstant(instant, zone)
        val day = moment.toLocalDate()
        val today = LocalDate.ofInstant(now, zone)

        return when (day) {
            today -> "오늘 ${clock(moment)}"
            today.minusDays(1) -> "어제 ${clock(moment)}"
            else -> "${day.year}. ${day.monthValue}. ${day.dayOfMonth}."
        }
    }

    private fun clock(moment: LocalDateTime): String =
        "%02d:%02d".format(moment.hour, moment.minute)
}
