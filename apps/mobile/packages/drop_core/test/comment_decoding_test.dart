import 'dart:convert';

import 'package:drop_core/drop_core.dart';
import 'package:test/test.dart';

/// DropCore `CommentDecodingTests.swift` 포팅.
/// `note_comments` 행의 실제 모양을 픽스처로 고정한다.
void main() {
  NoteComment decode(String json) =>
      NoteComment.fromJson(jsonDecode(json) as Map<String, Object?>);

  group('NoteComment 디코딩', () {
    test('note_comments 행을 디코딩한다', () {
      final comment = decode('''
      {
        "id": "1f0b7a4c-1111-2222-3333-444455556666",
        "note_id": "6f1c1b2e-6a1e-4a1a-9a4e-0a1b2c3d4e5f",
        "user_id": "9a9a9a9a-0000-1111-2222-333344445555",
        "body": "확인했습니다",
        "created_at": "2026-08-17T05:30:00.123456+00:00",
        "updated_at": "2026-08-17T05:30:00+00:00"
      }
      ''');

      expect(comment.id, '1f0b7a4c-1111-2222-3333-444455556666');
      expect(comment.noteId, '6f1c1b2e-6a1e-4a1a-9a4e-0a1b2c3d4e5f');
      expect(comment.body, '확인했습니다');
      // 분수초가 붙은 timestamptz도 붙지 않은 것도 둘 다 온다.
      expect(comment.createdAt, isNot(comment.updatedAt));
    });
  });
}
