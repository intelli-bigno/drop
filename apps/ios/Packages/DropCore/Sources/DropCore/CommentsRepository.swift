import Foundation

/// 댓글 데이터 접근 경계. 화면은 이 프로토콜만 알고, 테스트는 인메모리 구현을 쓴다.
///
/// 오류 타입은 `NotesRepositoryError`를 그대로 쓴다 — 화면에 뜨는 문구가 같아야 하고,
/// 같은 이유(인증·네트워크·거절·디코딩)로만 실패한다.
public protocol CommentsRepository: Sendable {
    /// 한 노트의 댓글을 오래된 순으로 가져온다. 댓글은 대화라 위에서 아래로 읽는다.
    func loadComments(noteID: String) async throws -> [NoteComment]

    /// 노트별 댓글 수. 목록 한 줄 행의 뱃지가 쓴다 —
    /// 노트마다 목록을 받아 오면 화면 하나에 수십 번의 왕복이 생긴다.
    func loadCommentCounts() async throws -> [String: Int]

    func createComment(noteID: String, body: String) async throws -> NoteComment

    /// 하드 삭제. 댓글에는 휴지통이 없다.
    func deleteComment(id: String) async throws
}
