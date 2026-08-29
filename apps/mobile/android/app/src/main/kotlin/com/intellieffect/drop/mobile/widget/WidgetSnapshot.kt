package com.intellieffect.drop.mobile.widget

import java.io.File
import java.util.Calendar
import java.util.Date
import java.util.TimeZone
import org.json.JSONObject

/**
 * 앱이 홈 화면 위젯에게 넘기는 요약 — **읽는 쪽**. 적는 쪽은 앱(drop_core, Dart)이다.
 *
 * 무엇을 보여줄지 고르고 자르는 규칙은 전부 `drop_core/lib/src/widget_snapshot.dart`에
 * 있고 테스트가 덮는다. 여기서는 이미 정해진 것을 읽어 배치만 한다 — iOS 위젯
 * (`ios/DropShell/DropShellCore.swift`)이 하는 일과 같다.
 *
 * 계약은 snake_case 키 + ISO8601 UTC 시각. 파일 이름·형식이 그 계약이다.
 */
data class WidgetNote(
    val id: String,
    /** 이미 한 줄로 접히고 잘린 상태. 위젯 쪽에서 더 손대지 않는다. */
    val excerpt: String,
    val createdAt: Date,
)

data class WidgetSnapshot(
    val notes: List<WidgetNote>,
    val generatedAt: Date,
) {
    val isEmpty: Boolean get() = notes.isEmpty()

    companion object {
        /** 작은 위젯에 실제로 보이는 줄 수. Dart 쪽 `maximumNoteCount`와 같은 값. */
        const val MAXIMUM_NOTE_COUNT = 3

        /** 앱이 아직 한 번도 쓰지 않았거나 파일이 깨졌을 때의 값. */
        val EMPTY = WidgetSnapshot(notes = emptyList(), generatedAt = Date(0))

        /**
         * 읽기는 실패하지 않는다. 깨진 값이 하나 있어도 나머지는 그린다 —
         * 위젯이 빈 화면으로 남는 것보다 낫다.
         */
        fun parse(json: String): WidgetSnapshot {
            return try {
                val root = JSONObject(json)
                val array = root.optJSONArray("notes")
                val notes = buildList {
                    for (index in 0 until (array?.length() ?: 0)) {
                        val item = array!!.optJSONObject(index) ?: continue
                        val id = item.optString("id")
                        val createdAt = parseIso8601(item.optString("created_at"))
                        if (id.isEmpty() || createdAt == null) continue
                        add(WidgetNote(id = id, excerpt = item.optString("excerpt"), createdAt = createdAt))
                    }
                }
                WidgetSnapshot(
                    notes = notes,
                    generatedAt = parseIso8601(root.optString("generated_at")) ?: Date(0),
                )
            } catch (_: Exception) {
                EMPTY
            }
        }

        private val ISO8601 =
            Regex("""^(\d{4})-(\d{2})-(\d{2})[Tt ](\d{2}):(\d{2}):(\d{2})(?:\.(\d+))?(Z|z|[+-]\d{2}:?\d{2})?$""")

        /**
         * `2026-08-30T05:12:33.123Z`를 읽는다.
         *
         * `java.time`을 쓰지 않는 이유는 minSdk다 — desugaring 설정을 Flutter 앱 전체에
         * 들이지 않고 이 한 곳에서 끝낸다. Dart가 적는 값은 항상 UTC(`Z`)지만,
         * 옛 파일·수기 편집을 대비해 오프셋도 받는다.
         */
        fun parseIso8601(raw: String?): Date? {
            val match = ISO8601.matchEntire(raw?.trim().orEmpty()) ?: return null
            val (year, month, day, hour, minute, second, fraction, zone) = match.destructured

            val calendar = Calendar.getInstance(TimeZone.getTimeZone("UTC"))
            calendar.clear()
            calendar.set(year.toInt(), month.toInt() - 1, day.toInt(), hour.toInt(), minute.toInt(), second.toInt())
            calendar.set(Calendar.MILLISECOND, fraction.take(3).padEnd(3, '0').toIntOrNull() ?: 0)

            val offsetMinutes = when {
                zone.isEmpty() || zone.equals("Z", ignoreCase = true) -> 0
                else -> {
                    val digits = zone.substring(1).replace(":", "")
                    val magnitude = digits.take(2).toInt() * 60 + digits.drop(2).toInt()
                    if (zone[0] == '-') -magnitude else magnitude
                }
            }
            return Date(calendar.timeInMillis - offsetMinutes * 60_000L)
        }
    }
}

/**
 * 스냅샷이 오가는 파일 하나. iOS는 App Group 컨테이너에 두지만 Android는 위젯이
 * 앱과 같은 UID로 돌아서 앱 내부 저장소면 충분하다 (`NativeShellChannel`).
 */
class WidgetSnapshotStore(containerDirectory: File) {
    val file = File(containerDirectory, FILE_NAME)

    fun read(): WidgetSnapshot =
        try {
            WidgetSnapshot.parse(file.readText())
        } catch (_: Exception) {
            WidgetSnapshot.EMPTY
        }

    companion object {
        /** Dart `WidgetSnapshotStore`가 적는 이름 그대로. */
        const val FILE_NAME = "widget-snapshot.json"
    }
}
