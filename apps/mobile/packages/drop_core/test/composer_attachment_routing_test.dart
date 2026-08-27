import 'package:drop_core/drop_core.dart';
import 'package:test/test.dart';

/// DropCore `ComposerAttachmentRoutingTests.swift` 포팅.
/// 컴포저에서 고른 미디어가 어느 노트에 붙는지 (BRU-131).
///
/// 홈 사진 선택기는 빈 노트를 새로 만들고 붙인다. 편집 시트는 지금 고치고
/// 있는 그 노트에 붙여야 한다 — 새 display_id가 생기면 안 된다.
void main() {
  group('컴포저 첨부 경로', () {
    test('편집 중인 노트 id가 있으면 그 노트에 붙인다', () {
      final destination =
          ComposerAttachmentRouting.destination(editingNoteId: 'existing-1');
      expect(destination,
          const ComposerAttachmentDestination.existing(noteId: 'existing-1'));
      expect(
        ComposerAttachmentRouting.noteIdToAttach(
          destination: destination,
          createdNoteId: 'new-2',
        ),
        'existing-1',
      );
    });

    test('새 노트는 만든 뒤에 그 id로 붙인다', () {
      final destination = ComposerAttachmentRouting.destination();
      expect(destination, const ComposerAttachmentDestination.createThenAttach());
      expect(
        ComposerAttachmentRouting.noteIdToAttach(destination: destination),
        isNull,
      );
      expect(
        ComposerAttachmentRouting.noteIdToAttach(
          destination: destination,
          createdNoteId: 'created-1',
        ),
        'created-1',
      );
    });

    test('기존 노트 경로는 새로 만든 id를 쓰지 않는다', () {
      final existing =
          ComposerAttachmentRouting.destination(editingNoteId: 'keep-me');
      final created = ComposerAttachmentRouting.destination();

      expect(existing, isNot(created));
      expect(
        ComposerAttachmentRouting.noteIdToAttach(
          destination: existing,
          createdNoteId: 'must-not-use',
        ),
        isNot('must-not-use'),
      );
    });
  });
}
