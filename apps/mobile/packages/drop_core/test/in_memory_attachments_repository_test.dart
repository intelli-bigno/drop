import 'dart:typed_data';

import 'package:drop_core/drop_core.dart';
import 'package:test/test.dart';

/// 컴포저(BRU-158)가 프리뷰·테스트에서 쓰는 인메모리 첨부 리포지토리.
/// 실제 Supabase 구현과 같은 계약 — 업로드가 행을 만들고, 실패 손잡이가 있다.
void main() {
  group('인메모리 첨부 리포지토리', () {
    test('업로드는 노트 id에 매인 첨부 행을 만든다', () async {
      final repository = InMemoryAttachmentsRepository();

      final attachment = await repository.upload(
        data: Uint8List.fromList([1, 2, 3]),
        fileName: '사진.png',
        type: AttachmentType.image,
        noteId: 'n-1',
      );

      expect(attachment.noteId, 'n-1');
      expect(attachment.type, AttachmentType.image);
      expect(attachment.filename, '사진.png');
      expect(attachment.size, 3);
      expect(repository.attachments, [attachment]);
    });

    test('업로드 실패 손잡이는 행을 만들지 않는다', () async {
      final repository = InMemoryAttachmentsRepository()
        ..uploadError = StateError('업로드 실패');

      await expectLater(
        repository.upload(
          data: Uint8List.fromList([1]),
          fileName: 'a.png',
          type: AttachmentType.image,
          noteId: 'n-1',
        ),
        throwsStateError,
      );
      expect(repository.attachments, isEmpty);
    });

    test('삭제는 그 행만 걷어낸다', () async {
      final repository = InMemoryAttachmentsRepository();
      final first = await repository.upload(
        data: Uint8List.fromList([1]),
        fileName: 'a.png',
        type: AttachmentType.image,
        noteId: 'n-1',
      );
      final second = await repository.upload(
        data: Uint8List.fromList([2]),
        fileName: 'b.mp4',
        type: AttachmentType.video,
        noteId: 'n-1',
      );

      await repository.delete(first);

      expect(repository.attachments, [second]);
    });
  });
}
