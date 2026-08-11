import Foundation

/// 목록 조회 결과(노트 / 첨부 / 태그)를 화면이 쓰는 형태로 합친다.
/// 순수 함수로 떼어 두어 네트워크 없이 검증한다.
public enum NoteAssembler {
    public static func assemble(
        notes: [Note],
        attachments: [Attachment],
        tagsByNoteID: [String: [Tag]]
    ) -> [Note] {
        // 주인 없는 첨부(삭제된 노트의 잔여물 등)는 여기서 자연스럽게 버려진다.
        let attachmentsByNoteID = Dictionary(grouping: attachments, by: \.noteID)

        return notes.map { note in
            note.replacingRelations(
                attachments: attachmentsByNoteID[note.id] ?? [],
                tags: tagsByNoteID[note.id] ?? []
            )
        }
    }

    /// 고정 먼저 → 고정 시각 최신순 → 생성 시각 최신순.
    /// 서버 정렬과 같은 규칙을 클라이언트에도 두어, 낙관적 갱신으로 끼워 넣은
    /// 노트가 새로고침 전후로 자리를 바꾸지 않게 한다.
    public static func sorted(_ notes: [Note]) -> [Note] {
        notes.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            if lhs.isPinned, rhs.isPinned {
                let lhsPinned = lhs.pinnedAt ?? .distantPast
                let rhsPinned = rhs.pinnedAt ?? .distantPast
                if lhsPinned != rhsPinned { return lhsPinned > rhsPinned }
            }
            return lhs.createdAt > rhs.createdAt
        }
    }
}

extension Note {
    func replacingRelations(attachments: [Attachment], tags: [Tag]) -> Note {
        Note(
            id: id,
            displayID: displayID,
            content: content,
            parentID: parentID,
            attachments: attachments,
            tags: tags,
            createdAt: createdAt,
            updatedAt: updatedAt,
            source: source,
            archivedAt: archivedAt,
            deletedAt: deletedAt,
            isDeleted: isDeleted,
            hasLink: hasLink,
            hasMedia: hasMedia,
            hasFiles: hasFiles,
            isLocked: isLocked,
            isPinned: isPinned,
            pinnedAt: pinnedAt,
            priority: priority
        )
    }
}
