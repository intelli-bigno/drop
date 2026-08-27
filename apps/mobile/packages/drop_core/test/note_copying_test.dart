import 'package:drop_core/drop_core.dart';
import 'package:test/test.dart';

/// DropCore `NoteCopyingTests.swift` 포팅.
/// 목록 더블탭이 클립보드에 넣는 문자열 (BRU-129).
void main() {
  Note note({required String content}) {
    final now = DateTime.now();
    return Note(
      id: 'n1',
      displayId: 42,
      content: content,
      createdAt: now,
      updatedAt: now,
      source: NoteSource.mobile,
    );
  }

  group('노트 복사', () {
    test('클립보드에는 본문만 들어간다', () {
      const body = '장보기: 우유, 커피 원두';
      expect(NoteCopying.clipboardString(note(content: body)), body);
    });

    test('본문이 비어 있으면 빈 문자열이다', () {
      expect(NoteCopying.clipboardString(note(content: '')), '');
    });

    test('참조 링크나 display id는 넣지 않는다', () {
      final copied = NoteCopying.clipboardString(note(content: '본문만'));
      expect(copied, '본문만');
      expect(copied.contains('drop://'), isFalse);
      expect(copied.contains('42'), isFalse);
    });

    test('선택 모드에서는 더블탭이 복사하지 않는다', () {
      expect(NoteCopying.shouldCopyOnDoubleTap(isSelecting: true), isFalse);
      expect(NoteCopying.shouldCopyOnDoubleTap(isSelecting: false), isTrue);
    });
  });
}
