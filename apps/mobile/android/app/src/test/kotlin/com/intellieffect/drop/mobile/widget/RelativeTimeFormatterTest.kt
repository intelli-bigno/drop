package com.intellieffect.drop.mobile.widget

import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test

/**
 * 위젯 줄에 붙는 시간 문구. iOS 위젯(`DropShellCore.swift`)과 같은 규칙을 지키는지 본다 —
 * 같은 노트가 두 플랫폼에서 다른 시간으로 보이면 그 표시를 믿지 못하게 된다.
 */
class RelativeTimeFormatterTest {
    private val formatter = RelativeTimeFormatter()

    @Before
    fun fixTimeZone() {
        // "오늘/어제"는 로컬 달력으로 가른다 — 테스트가 도는 기기의 시간대에 흔들리면 안 된다.
        TimeZone.setDefault(TimeZone.getTimeZone("Asia/Seoul"))
    }

    private val now = at(2026, 8, 30, 14, 0)

    @Test
    fun `1분 안쪽은 초로 말한다`() {
        assertEquals("0초전", formatter.format(now, now))
        assertEquals("30초전", formatter.format(Date(now.time - 30_000), now))
    }

    @Test
    fun `1시간 안쪽은 분으로 말한다`() {
        assertEquals("1분전", formatter.format(Date(now.time - 60_000), now))
        assertEquals("59분전", formatter.format(Date(now.time - 59 * 60_000L), now))
    }

    @Test
    fun `같은 날이면 오늘과 시각`() {
        assertEquals("오늘 09:05", formatter.format(at(2026, 8, 30, 9, 5), now))
    }

    @Test
    fun `날짜가 넘어가면 어제 — 24시간이 안 지났어도`() {
        assertEquals("어제 23:30", formatter.format(at(2026, 8, 29, 23, 30), now))
    }

    @Test
    fun `그보다 오래되면 날짜로 적는다`() {
        assertEquals("2026. 8. 3.", formatter.format(at(2026, 8, 3, 9, 0), now))
    }

    @Test
    fun `미래 시각도 음수로 새지 않는다`() {
        assertEquals("0초전", formatter.format(Date(now.time + 5_000), now))
    }

    private fun at(year: Int, month: Int, day: Int, hour: Int, minute: Int): Date =
        Calendar.getInstance(TimeZone.getTimeZone("Asia/Seoul"), Locale.KOREA).apply {
            clear()
            set(year, month - 1, day, hour, minute, 0)
        }.time
}
