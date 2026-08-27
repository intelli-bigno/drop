/// INSERT payload 정본. DropCore `NoteInsert`/`CommentInsert`/`TagInsert`/
/// `AttachmentInsert` 대응.
///
/// INSERT 정책이 `user_id = auth.uid()`를 요구하는데 `user_id`에는 기본값이 없다.
/// 즉 **클라이언트가 넣지 않으면 NULL이 들어가 RLS가 거부한다.**
/// "RLS가 알아서 채워준다"고 착각하기 쉬운 자리라 payload를 함수로 못박는다.
/// 키는 전부 snake_case — 아니면 서버가 컬럼을 못 찾아 조용히 실패한다.
library;

import '../drop_json.dart';

Map<String, Object?> noteInsertPayload({
  required String content,
  String? parentId,
  required String userId,
}) =>
    {
      'content': content,
      'parent_id': ?parentId,
      'user_id': userId,
      'source': 'mobile',
    };

Map<String, Object?> commentInsertPayload({
  required String noteId,
  required String userId,
  required String body,
}) =>
    {
      'note_id': noteId,
      'user_id': userId,
      'body': body,
    };

Map<String, Object?> tagInsertPayload({
  required String name,
  required String userId,
  required DateTime lastUsedAt,
}) =>
    {
      'name': name,
      'user_id': userId,
      'last_used_at': formatPostgresTimestamp(lastUsedAt),
    };

Map<String, Object?> attachmentInsertPayload({
  required String noteId,
  required String type,
  required String storagePath,
  required String filename,
  required String mimeType,
  required int size,
}) =>
    {
      'note_id': noteId,
      'type': type,
      'storage_path': storagePath,
      'filename': filename,
      'mime_type': mimeType,
      'size': size,
    };
