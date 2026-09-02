/// 행 스와이프를 놓았을 때 열지 닫을지의 판정 (BRU-207).
///
/// 제스처 자체는 위젯의 몫이지만 **판정은 순수 함수**라 위젯 트리 없이 검증한다 —
/// `resolveNoteTap`(`lib/notes/note_tap.dart`)과 같은 태도다.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/widgets/drop_swipe_row.dart';

void main() {
  const extent = 100.0;

  group('resolveSwipeSettle', () {
    test('절반을 못 넘기고 손을 떼면 닫힌다', () {
      expect(
        resolveSwipeSettle(offset: 40, actionExtent: extent, velocity: 0),
        SwipeSettle.closed,
      );
    });

    test('절반을 넘겨 끌었으면 열린다', () {
      expect(
        resolveSwipeSettle(offset: 60, actionExtent: extent, velocity: 0),
        SwipeSettle.open,
      );
    });

    test('정확히 절반이면 열린다 — 애매한 자리는 사용자가 의도한 쪽으로 민다', () {
      expect(
        resolveSwipeSettle(offset: 50, actionExtent: extent, velocity: 0),
        SwipeSettle.open,
      );
    });

    test('조금만 끌어도 여는 방향으로 튕기면 열린다', () {
      expect(
        resolveSwipeSettle(offset: 12, actionExtent: extent, velocity: -900),
        SwipeSettle.open,
      );
    });

    test('거의 다 열렸어도 닫는 방향으로 튕기면 닫힌다', () {
      expect(
        resolveSwipeSettle(offset: 92, actionExtent: extent, velocity: 900),
        SwipeSettle.closed,
      );
    });

    test('느린 움직임은 튕김으로 치지 않는다 — 끌린 거리가 정한다', () {
      expect(
        resolveSwipeSettle(offset: 20, actionExtent: extent, velocity: -200),
        SwipeSettle.closed,
      );
      expect(
        resolveSwipeSettle(offset: 80, actionExtent: extent, velocity: 200),
        SwipeSettle.open,
      );
    });

    test('열 것이 없으면 언제나 닫힘 — 0으로 나누지 않는다', () {
      expect(
        resolveSwipeSettle(offset: 0, actionExtent: 0, velocity: -900),
        SwipeSettle.closed,
      );
    });
  });
}
