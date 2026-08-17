package com.intellieffect.drop.core

import java.io.File
import java.time.Instant
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * 위젯 한 줄에 들어가는 노트 (iOS `WidgetNote`와 같은 모양).
 *
 * `Note`를 그대로 싣지 않는 이유는 둘이다: 첨부·태그까지 파일에 복사할 이유가 없고,
 * 필드가 바뀔 때마다 위젯이 못 읽는 옛 파일을 만들게 된다. 위젯이 그리는 것만 담는다.
 */
@Serializable
data class WidgetNote(
    val id: String,
    /** 이미 한 줄로 접히고 잘린 상태. 위젯 쪽에서 더 손대지 않는다. */
    val excerpt: String,
    @Serializable(with = InstantSerializer::class)
    @SerialName("created_at")
    val createdAt: Instant,
)

/**
 * 앱이 위젯에게 넘기는 요약 한 벌 (iOS `WidgetSnapshot`의 이식본).
 *
 * 위젯은 Supabase에 접속하지 않는다 — 앱 프로세스가 죽어 있을 수도, 세션이 없을 수도 있다.
 * 앱이 노트를 불러올 때마다 이 스냅샷을 파일에 적어 두고 위젯은 그것만 읽는다.
 */
@Serializable
data class WidgetSnapshot(
    val notes: List<WidgetNote> = emptyList(),
    @Serializable(with = InstantSerializer::class)
    @SerialName("generated_at")
    val generatedAt: Instant = Instant.EPOCH,
) {
    val isEmpty: Boolean get() = notes.isEmpty()

    companion object {
        /** 위젯에 실제로 보이는 줄 수. iOS와 같은 값이어야 두 플랫폼의 위젯이 같아 보인다. */
        const val MAXIMUM_NOTE_COUNT = 3

        /** 말줄임표를 포함한 발췌 최대 길이. */
        const val EXCERPT_LIMIT = 80

        /** 본문이 빈 노트(사진만 붙인 노트 등)를 대신하는 문구. */
        const val EMPTY_CONTENT_PLACEHOLDER = "(내용 없음)"

        /** 앱이 아직 한 번도 쓰지 않았거나 파일이 깨졌을 때의 값. */
        val EMPTY = WidgetSnapshot()

        /** 앱이 들고 있는 목록에서 위젯용 요약을 만든다. */
        fun from(notes: List<Note>, generatedAt: Instant = Instant.now()): WidgetSnapshot =
            WidgetSnapshot(
                notes = notes
                    // 보관·휴지통 노트가 위젯에 뜨면 지운 줄 알았던 것이 계속 보인다.
                    .filter { it.isActive }
                    .sortedByDescending { it.createdAt }
                    .take(MAXIMUM_NOTE_COUNT)
                    .map { WidgetNote(id = it.id, excerpt = excerpt(it.content), createdAt = it.createdAt) },
                generatedAt = generatedAt,
            )

        /** 본문을 위젯 한 줄에 맞게 접고 자른다. */
        fun excerpt(content: String): String {
            val flattened = content.split(Regex("\\s+")).filter { it.isNotEmpty() }.joinToString(" ")
            return when {
                flattened.isEmpty() -> EMPTY_CONTENT_PLACEHOLDER
                flattened.length <= EXCERPT_LIMIT -> flattened
                else -> flattened.take(EXCERPT_LIMIT - 1) + "…"
            }
        }
    }
}

/**
 * 스냅샷이 오가는 파일 하나.
 *
 * iOS는 App Group을 쓰지만 Android의 위젯은 같은 프로세스·같은 앱 저장소를 보므로
 * 앱 내부 파일로 충분하다.
 */
class WidgetSnapshotStore(private val file: File) {
    fun write(snapshot: WidgetSnapshot) {
        file.parentFile?.mkdirs()
        // 임시 파일에 쓰고 옮긴다 — 쓰는 중에 위젯이 읽으면 잘린 JSON을 보게 된다.
        val temporary = File(file.parentFile, "${file.name}.tmp")
        temporary.writeText(dropJson.encodeToString(WidgetSnapshot.serializer(), snapshot))
        if (!temporary.renameTo(file)) {
            file.writeText(temporary.readText())
            temporary.delete()
        }
    }

    /** 읽기는 실패하지 않는다. 파일이 없든 깨졌든 위젯은 빈 상태로라도 그려져야 한다. */
    fun read(): WidgetSnapshot = runCatching {
        dropJson.decodeFromString(WidgetSnapshot.serializer(), file.readText())
    }.getOrElse { WidgetSnapshot.EMPTY }
}
