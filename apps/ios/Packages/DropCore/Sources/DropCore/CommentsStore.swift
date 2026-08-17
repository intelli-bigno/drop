import Foundation
import Observation

/// 댓글 화면과 목록 뱃지가 함께 보는 상태.
///
/// `NotesStore`와 **따로** 둔다 — 댓글은 노트가 아니고, 목록·검색·위젯이 보는
/// `visibleNotes`에 절대 섞이면 안 된다(BRU-62의 별도 테이블 설계를 상태에서도 지킨다).
///
/// 실패 규칙은 `NotesStore`와 같다(BRU-51):
/// 로드 실패는 보고 있던 목록을 지우지 않고, 취소는 오류가 아니며,
/// 겹친 로드는 새 요청을 보내지 않고 진행 중인 것이 끝날 때까지 기다린다.
@MainActor
@Observable
public final class CommentsStore {
    /// 노트별 댓글 목록. 열어 본 노트만 들어 있다.
    private var commentsByNoteID: [String: [NoteComment]] = [:]
    /// 노트별 댓글 수 — 목록 한 줄 행의 뱃지가 쓴다. 목록을 열지 않아도 채워진다.
    private var countsByNoteID: [String: Int] = [:]

    public private(set) var isLoading = false
    public private(set) var errorMessage: String?

    private let repository: any CommentsRepository
    /// 지금 도는 로드. 노트별로 하나씩 — 다른 노트의 로드는 서로를 막지 않는다.
    private var inFlight: [String: Task<Void, Never>] = [:]
    private var countsInFlight: Task<Void, Never>?

    public init(repository: any CommentsRepository) {
        self.repository = repository
    }

    public func comments(for noteID: String) -> [NoteComment] {
        commentsByNoteID[noteID] ?? []
    }

    /// 뱃지 숫자. 모르는 노트는 0이고, 화면은 0이면 아무것도 그리지 않는다.
    public func count(for noteID: String) -> Int {
        countsByNoteID[noteID] ?? 0
    }

    // MARK: - 로드

    public func load(noteID: String) async {
        if let existing = inFlight[noteID] {
            await existing.value
            return
        }

        let task = Task { [self] in
            await performLoad(noteID: noteID)
            inFlight[noteID] = nil
        }
        inFlight[noteID] = task
        await task.value
    }

    /// 목록 화면이 뱃지를 채우기 위해 한 번 부른다.
    public func loadCounts() async {
        if let countsInFlight {
            await countsInFlight.value
            return
        }

        let task = Task { [self] in
            await performLoadCounts()
            countsInFlight = nil
        }
        countsInFlight = task
        await task.value
    }

    private func performLoad(noteID: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let loaded = try await repository.loadComments(noteID: noteID)
            commentsByNoteID[noteID] = loaded.sorted { $0.createdAt < $1.createdAt }
            // 뱃지와 실제 목록이 어긋나면 어느 쪽을 믿어야 할지 알 수 없다.
            countsByNoteID[noteID] = loaded.count
        } catch where error.isCancellation {
            // 취소는 실패가 아니다. 보고 있던 목록을 그대로 둔다.
        } catch {
            // 실패한 것은 "새 목록을 받아오는 일"이지 이미 받아 둔 목록이 아니다 (BRU-51).
            errorMessage = RepositoryErrorMessage.text(for: error)
        }
        isLoading = false
    }

    private func performLoadCounts() async {
        do {
            countsByNoteID = try await repository.loadCommentCounts()
        } catch where error.isCancellation {
        } catch {
            errorMessage = RepositoryErrorMessage.text(for: error)
        }
    }

    // MARK: - 작성 · 삭제

    /// 저장을 기다리지 않고 먼저 끼워 넣는다. 실패하면 걷어낸다 —
    /// 남겨 두면 저장되지도 않은 댓글이 화면에 남는다.
    public func add(noteID: String, body: String) async {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        // DB가 `length(btrim(body)) > 0`을 요구한다. 서버까지 가서 거절당하는 대신
        // 여기서 조용히 막는다 — 빈 입력은 오류가 아니라 아무 일도 아니다.
        guard !trimmed.isEmpty else { return }

        let placeholder = NoteComment(
            id: "임시-\(UUID().uuidString)",
            noteID: noteID,
            body: trimmed,
            createdAt: Date(),
            updatedAt: Date()
        )
        append(placeholder, to: noteID)

        do {
            let created = try await repository.createComment(noteID: noteID, body: trimmed)
            replace(id: placeholder.id, in: noteID, with: created)
        } catch {
            remove(id: placeholder.id, from: noteID)
            errorMessage = RepositoryErrorMessage.text(for: error)
        }
    }

    /// 하드 삭제 — 댓글에는 휴지통이 없다.
    public func delete(id: String, from noteID: String) async {
        let backup = comments(for: noteID)
        remove(id: id, from: noteID)

        do {
            try await repository.deleteComment(id: id)
        } catch {
            commentsByNoteID[noteID] = backup
            countsByNoteID[noteID] = backup.count
            errorMessage = RepositoryErrorMessage.text(for: error)
        }
    }

    public func dismissError() {
        errorMessage = nil
    }

    // MARK: - 내부

    private func append(_ comment: NoteComment, to noteID: String) {
        var list = comments(for: noteID)
        list.append(comment)
        commentsByNoteID[noteID] = list.sorted { $0.createdAt < $1.createdAt }
        countsByNoteID[noteID] = list.count
    }

    private func replace(id: String, in noteID: String, with comment: NoteComment) {
        var list = comments(for: noteID)
        guard let index = list.firstIndex(where: { $0.id == id }) else { return }
        list[index] = comment
        commentsByNoteID[noteID] = list.sorted { $0.createdAt < $1.createdAt }
    }

    private func remove(id: String, from noteID: String) {
        var list = comments(for: noteID)
        list.removeAll { $0.id == id }
        commentsByNoteID[noteID] = list
        countsByNoteID[noteID] = list.count
    }
}
