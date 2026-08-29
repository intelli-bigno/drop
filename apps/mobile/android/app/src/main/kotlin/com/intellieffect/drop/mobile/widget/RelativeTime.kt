package com.intellieffect.drop.mobile.widget

import java.util.Calendar
import java.util.Date
import java.util.Locale

/**
 * 노트 줄에 붙는 상대 시간 문구.
 *
 * 문구 규칙의 정본은 앱 쪽(`drop_core`)이고 iOS 위젯도 같은 규칙을 베껴 쓴다
 * (`ios/DropShell/DropShellCore.swift`의 `RelativeTimeFormatter`) — 위젯이 앱과
 * 다른 문구를 보여 주면 같은 노트가 두 얼굴이 된다.
 */
class RelativeTimeFormatter(private val locale: Locale = Locale.KOREA) {

    fun format(date: Date, now: Date = Date()): String {
        val elapsedSeconds = ((now.time - date.time) / 1000L).coerceAtLeast(0L)
        if (elapsedSeconds < 60) return "${elapsedSeconds}초전"

        val minutes = elapsedSeconds / 60
        if (minutes < 60) return "${minutes}분전"

        val day = startOfDay(date)
        val today = startOfDay(now)

        if (day == today) return "오늘 ${clockTime(date)}"
        if (day == today - ONE_DAY_MILLIS) return "어제 ${clockTime(date)}"

        val parts = calendarAt(date)
        return "${parts.get(Calendar.YEAR)}. ${parts.get(Calendar.MONTH) + 1}. ${parts.get(Calendar.DAY_OF_MONTH)}."
    }

    private fun calendarAt(date: Date): Calendar =
        Calendar.getInstance(locale).apply { time = date }

    /**
     * "오늘/어제"는 경과 시간이 아니라 **달력 날짜**로 가른다 — 23시간 전이어도
     * 날짜가 넘어갔으면 어제다.
     */
    private fun startOfDay(date: Date): Long =
        calendarAt(date).apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis

    private fun clockTime(date: Date): String {
        val parts = calendarAt(date)
        return String.format(
            Locale.US,
            "%02d:%02d",
            parts.get(Calendar.HOUR_OF_DAY),
            parts.get(Calendar.MINUTE),
        )
    }

    private companion object {
        /**
         * 서머타임이 있는 지역에서는 하루가 24시간이 아니지만, 한국은 DST가 없고
         * 이 문구는 "어제인가"만 가린다 — 어긋나도 날짜 표기로 떨어질 뿐이다.
         */
        const val ONE_DAY_MILLIS = 24 * 60 * 60 * 1000L
    }
}
