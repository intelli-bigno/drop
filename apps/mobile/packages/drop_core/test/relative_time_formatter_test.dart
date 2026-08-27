import 'package:drop_core/drop_core.dart';
import 'package:test/test.dart';

/// DropCore `RelativeTimeFormatterTests.swift` 포팅.
/// 두 앱이 병렬 운영되는 동안 같은 노트가 같은 문구로 보여야 한다.
void main() {
  // 2026-08-12 14:30:00 (로컬)
  final now = DateTime(2026, 8, 12, 14, 30);

  group('상대 시간 표기', () {
    test('1분 미만은 초 단위로 표기한다', () {
      expect(
        relativeTimeString(now.subtract(const Duration(seconds: 5)), now: now),
        '5초전',
      );
      expect(
        relativeTimeString(now.subtract(const Duration(seconds: 59)), now: now),
        '59초전',
      );
    });

    test('1시간 미만은 분 단위로 표기한다', () {
      expect(
        relativeTimeString(now.subtract(const Duration(minutes: 1)), now: now),
        '1분전',
      );
      expect(
        relativeTimeString(now.subtract(const Duration(minutes: 59)), now: now),
        '59분전',
      );
    });

    test('오늘이면 시:분을 두 자리로 붙인다', () {
      final today0905 =
          now.subtract(const Duration(hours: 5, minutes: 25));
      expect(relativeTimeString(today0905, now: now), '오늘 09:05');
    });

    test('어제면 어제 시:분으로 표기한다', () {
      final yesterday2300 =
          now.subtract(const Duration(hours: 15, minutes: 30));
      expect(relativeTimeString(yesterday2300, now: now), '어제 23:00');
    });

    test('그 이전은 연. 월. 일. 로 표기한다', () {
      final twoDaysAgo = now.subtract(const Duration(days: 2));
      expect(relativeTimeString(twoDaysAgo, now: now), '2026. 8. 10.');
    });

    test('미래 시각은 0초전으로 떨어진다', () {
      expect(
        relativeTimeString(now.add(const Duration(seconds: 30)), now: now),
        '0초전',
      );
    });
  });
}
