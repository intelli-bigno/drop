package com.intellieffect.drop.mobile.widget

import java.io.File
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import kotlin.io.path.createTempDirectory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 위젯이 앱의 스냅샷 파일을 실제로 읽어 내는지 — 에뮬레이터 없이 도는 자리.
 *
 * 스냅샷을 **만드는** 규칙은 여기서 다시 시험하지 않는다(drop_core Dart 테스트가 정본).
 * 여기서 지키는 것은 계약 하나다: Dart가 적은 그 문자열을 Kotlin이 같은 값으로 읽는가.
 */
class WidgetSnapshotTest {

    /** Dart `WidgetSnapshot.toJson()` + `jsonEncode`가 실제로 내놓는 모양 그대로. */
    private val dartOutput = """
        {"notes":[
          {"id":"n1","excerpt":"장보기: 우유, 계란","created_at":"2026-08-30T05:12:33.123Z"},
          {"id":"n2","excerpt":"회의 전에 지표 확인하기","created_at":"2026-08-30T04:12:33.000Z"}
        ],"generated_at":"2026-08-30T05:13:00.000Z"}
    """.trimIndent()

    @Test
    fun `앱이 적은 스냅샷을 그대로 읽는다`() {
        val snapshot = WidgetSnapshot.parse(dartOutput)

        assertEquals(listOf("n1", "n2"), snapshot.notes.map { it.id })
        assertEquals("장보기: 우유, 계란", snapshot.notes[0].excerpt)
        assertEquals(utc(2026, 8, 30, 5, 12, 33, 123), snapshot.notes[0].createdAt)
        assertEquals(utc(2026, 8, 30, 5, 13, 0, 0), snapshot.generatedAt)
    }

    @Test
    fun `분수초가 없는 시각도 읽는다`() {
        assertEquals(utc(2026, 8, 30, 5, 12, 33, 0), WidgetSnapshot.parseIso8601("2026-08-30T05:12:33Z"))
    }

    @Test
    fun `오프셋이 붙은 시각은 UTC로 환산한다`() {
        assertEquals(utc(2026, 8, 30, 0, 0, 0, 0), WidgetSnapshot.parseIso8601("2026-08-30T09:00:00+09:00"))
    }

    @Test
    fun `깨진 파일은 빈 스냅샷이 된다`() {
        // 위젯은 어떤 입력에도 그려져야 한다 — 예외를 던지면 런처에 "위젯을 불러올 수 없음"이 남는다.
        assertTrue(WidgetSnapshot.parse("{").isEmpty)
        assertTrue(WidgetSnapshot.parse("").isEmpty)
        assertTrue(WidgetSnapshot.parse("""{"notes":[]}""").isEmpty)
    }

    @Test
    fun `시각을 못 읽는 줄은 건너뛰고 나머지를 그린다`() {
        val snapshot = WidgetSnapshot.parse(
            """{"notes":[{"id":"n1","excerpt":"a","created_at":"어제"},
               {"id":"n2","excerpt":"b","created_at":"2026-08-30T05:00:00Z"}],
               "generated_at":"2026-08-30T05:13:00.000Z"}""",
        )

        assertEquals(listOf("n2"), snapshot.notes.map { it.id })
    }

    @Test
    fun `파일이 없으면 빈 스냅샷을 돌려준다`() {
        val directory = createTempDirectory("drop-widget-test").toFile()
        assertTrue(WidgetSnapshotStore(directory).read().isEmpty)
    }

    @Test
    fun `앱이 적은 파일 이름을 그대로 본다`() {
        val directory = createTempDirectory("drop-widget-test").toFile()
        // Dart `WidgetSnapshotStore`가 컨테이너 루트에 적는 이름.
        File(directory, "widget-snapshot.json").writeText(dartOutput)

        assertEquals(2, WidgetSnapshotStore(directory).read().notes.size)
    }

    private fun utc(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int, millis: Int): Date =
        Calendar.getInstance(TimeZone.getTimeZone("UTC"), Locale.US).apply {
            clear()
            set(year, month - 1, day, hour, minute, second)
            set(Calendar.MILLISECOND, millis)
        }.time
}
