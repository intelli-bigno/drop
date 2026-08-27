import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/notes/note_tap.dart';

void main() {
  group('resolveNoteTap — 탭 계약 (BRU-77 · BRU-129)', () {
    test('싱글탭은 뷰어를 연다', () {
      expect(
        resolveNoteTap(isSelecting: false, count: 1),
        NoteTapResult.openViewer,
      );
    });

    test('더블탭은 본문을 복사한다', () {
      expect(
        resolveNoteTap(isSelecting: false, count: 2),
        NoteTapResult.copyContent,
      );
    });

    test('선택 모드에서는 싱글탭·더블탭 모두 토글만 한다', () {
      expect(
        resolveNoteTap(isSelecting: true, count: 1),
        NoteTapResult.toggleSelection,
      );
      expect(
        resolveNoteTap(isSelecting: true, count: 2),
        NoteTapResult.toggleSelection,
      );
    });
  });
}
