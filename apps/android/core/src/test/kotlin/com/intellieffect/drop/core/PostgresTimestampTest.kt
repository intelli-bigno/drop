package com.intellieffect.drop.core

import java.time.Instant
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

/**
 * 한 컬럼에서 여러 모양이 섞여 온다. iOS도 같은 이유로 포매터를 둘 두고 있다 —
 * 한쪽만 받아들이면 목록 전체가 파싱 실패로 비어 버린다.
 */
class PostgresTimestampTest {
    private val expected: Instant = Instant.parse("2026-08-17T07:34:01Z")

    @Test
    fun `분수초가 붙은 값과 안 붙은 값을 모두 읽는다`() {
        assertEquals(expected, PostgresTimestamp.parse("2026-08-17T07:34:01Z"))
        assertEquals(
            expected.plusMillis(453),
            PostgresTimestamp.parse("2026-08-17T07:34:01.453Z"),
        )
    }

    /** PostgREST가 `+00:00`을, psql 스타일 덤프가 `+00`을 준다. */
    @Test
    fun `오프셋 표기가 달라도 읽는다`() {
        assertEquals(expected, PostgresTimestamp.parse("2026-08-17T07:34:01+00:00"))
        assertEquals(expected, PostgresTimestamp.parse("2026-08-17T07:34:01+00"))
        assertEquals(expected, PostgresTimestamp.parse("2026-08-17 07:34:01+00"))
        assertEquals(
            expected.minusSeconds(9 * 3600),
            PostgresTimestamp.parse("2026-08-17T07:34:01+09:00"),
        )
    }

    @Test
    fun `알 수 없는 값은 null이다`() {
        assertNull(PostgresTimestamp.parse("어제"))
    }

    @Test
    fun `되돌려 쓰면 다시 읽을 수 있다`() {
        assertEquals(expected, PostgresTimestamp.parse(PostgresTimestamp.format(expected)))
    }
}
