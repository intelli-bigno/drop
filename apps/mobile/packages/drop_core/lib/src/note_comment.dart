import 'drop_json.dart';

/// 노트에 달린 댓글. **노트가 아니다** — 태그·첨부·우선순위·보관·잠금이 없고,
/// 목록·검색·Inbox·위젯 어디에도 노트로 나타나지 않는다 (BRU-62의 별도 테이블 설계).
///
/// 소프트 삭제도 없다. 지우면 즉시 사라지고, 노트를 휴지통에 넣어도 댓글은 남는다.
/// DropCore `NoteComment.swift` 대응.
class NoteComment {
  final String id;
  final String noteId;
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NoteComment({
    required this.id,
    required this.noteId,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
  });

  factory NoteComment.fromJson(Map<String, Object?> json) => NoteComment(
        id: json['id'] as String,
        noteId: json['note_id'] as String,
        body: json['body'] as String,
        createdAt: parsePostgresTimestamp(json['created_at'] as String),
        updatedAt: parsePostgresTimestamp(json['updated_at'] as String),
      );

  @override
  bool operator ==(Object other) =>
      other is NoteComment &&
      other.id == id &&
      other.noteId == noteId &&
      other.body == body &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(id, noteId, body, createdAt, updatedAt);

  @override
  String toString() => 'NoteComment($id, note: $noteId)';
}
