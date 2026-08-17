package com.intellieffect.drop.core

import java.time.Instant
import java.time.OffsetDateTime
import java.time.format.DateTimeFormatter
import java.time.format.DateTimeParseException
import kotlinx.serialization.KSerializer
import kotlinx.serialization.descriptors.PrimitiveKind
import kotlinx.serialization.descriptors.PrimitiveSerialDescriptor
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.Json

/**
 * Postgres `timestamptz` 문자열 ↔ [Instant].
 *
 * 한 컬럼에서 여러 모양이 섞여 온다 — 분수초가 붙은 값과 안 붙은 값, `+00:00`과 `+00`,
 * `T` 대신 공백. 한 군데서 전부 받아들인다 (iOS `DropJSON`이 같은 이유로 두 포매터를 둔다).
 */
object PostgresTimestamp {
    fun parse(raw: String): Instant? {
        val normalized = normalize(raw)
        return runCatching { Instant.parse(normalized) }
            .recoverCatching { OffsetDateTime.parse(normalized).toInstant() }
            .getOrNull()
    }

    fun format(instant: Instant): String = DateTimeFormatter.ISO_INSTANT.format(instant)

    private fun normalize(raw: String): String {
        val trimmed = raw.trim().replace(' ', 'T')
        // `+00`처럼 분이 빠진 오프셋은 java.time이 받지 않는다.
        return SHORT_OFFSET.replace(trimmed) { "${it.groupValues[1]}:00" }
    }

    private val SHORT_OFFSET = Regex("([+-]\\d{2})$")
}

/** JSON에서 Postgres 시각을 [Instant]로 읽는다. */
object InstantSerializer : KSerializer<Instant> {
    override val descriptor: SerialDescriptor =
        PrimitiveSerialDescriptor("PostgresTimestamp", PrimitiveKind.STRING)

    override fun deserialize(decoder: Decoder): Instant {
        val raw = decoder.decodeString()
        return PostgresTimestamp.parse(raw)
            ?: throw DateTimeParseException("시각 형식을 알 수 없습니다: $raw", raw, 0)
    }

    override fun serialize(encoder: Encoder, value: Instant) {
        encoder.encodeString(PostgresTimestamp.format(value))
    }
}

/**
 * 프로젝트 전체가 쓰는 JSON 설정.
 *
 * `ignoreUnknownKeys`가 핵심이다 — 서버에 컬럼이 하나 늘어도 목록 전체가 깨지면 안 된다.
 */
val dropJson: Json = Json {
    ignoreUnknownKeys = true
    // null을 굳이 실어 보내지 않는다. PATCH 본문에 null을 넣으면 "컬럼을 비워라"가 되므로
    // 비우려는 자리에서는 명시적으로 JsonNull을 쓴다.
    explicitNulls = false
    encodeDefaults = true
}
