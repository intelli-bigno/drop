import 'package:drop_core/drop_core.dart';
import 'package:test/test.dart';

/// DropCore `NoteDateGrouperTests.swift` 포팅.
/// 목록을 날짜 섹션으로 묶는 순수 로직. 화면 없이 검증한다.
///
/// Swift 판은 `Calendar(timeZone:)`을 주입한다. Dart 판은 같은 계약을
/// UTC 오프셋 주입으로 지킨다 (KST = +9h).
void main() {
  const kst = Duration(hours: 9);
  const grouper = NoteDateGrouper(utcOffset: kst);

  /// KST 벽시계 시각을 UTC DateTime으로.
  DateTime date(int year, int month, int day, [int hour = 0, int minute = 0]) =>
      DateTime.utc(year, month, day, hour, minute).subtract(kst);

  /// 2026-08-12 14:30:00 KST
  final now = date(2026, 8, 12, 14, 30);

  Note note(String id, {required DateTime createdAt, bool isPinned = false}) =>
      Note(
        id: id,
        displayId: 0,
        content: id,
        createdAt: createdAt,
        updatedAt: createdAt,
        source: NoteSource.mobile,
        isPinned: isPinned,
      );

  group('노트 날짜 섹션', () {
    test('빈 목록은 섹션도 없다', () {
      expect(grouper.sectionsForNotes([], now: now), isEmpty);
      expect(grouper.sections([], now: now), isEmpty);
    });

    // 스레드(BRU-60)

    /// 자식은 자기 날짜가 아니라 **부모가 속한 섹션**에 붙는다. 자기 날짜로 나누면
    /// 스레드가 날짜 경계에서 쪼개져 애초 문제(맥락 끊김)가 그대로 남는다.
    test('답글은 자기 날짜가 아니라 부모의 섹션에 붙는다', () {
      final parent = note('부모', createdAt: date(2026, 8, 9, 10));
      final reply = Note(
        id: '답글',
        displayId: 0,
        content: '답글',
        parentId: '부모',
        createdAt: date(2026, 8, 12, 10),
        updatedAt: date(2026, 8, 12, 10),
        source: NoteSource.mobile,
      );

      final sections = grouper.sections(
        NoteHierarchy.rows(visible: [parent, reply], context: [parent, reply]),
        now: now,
      );

      // 답글은 오늘 쓴 것이지만 부모가 있는 "3일 전"에 함께 있어야 한다.
      expect(sections.map((s) => s.title), ['3일 전']);
      expect(sections[0].rows.map((r) => r.note.id), ['부모', '답글']);
      expect(sections[0].rows.map((r) => r.depth), [0, 1]);
    });

    test('고정한 노트의 답글은 고정 섹션까지 따라간다', () {
      final parent =
          note('고정부모', createdAt: date(2026, 1, 2), isPinned: true);
      final reply = Note(
        id: '답글',
        displayId: 0,
        content: '답글',
        parentId: '고정부모',
        createdAt: date(2026, 8, 12, 10),
        updatedAt: date(2026, 8, 12, 10),
        source: NoteSource.mobile,
      );

      final sections = grouper.sections(
        NoteHierarchy.rows(visible: [parent, reply], context: [parent, reply]),
        now: now,
      );

      expect(sections.map((s) => s.title), ['고정']);
      expect(sections[0].rows.map((r) => r.note.id), ['고정부모', '답글']);
    });

    test('오늘·어제·N일 전으로 제목을 붙인다', () {
      final sections = grouper.sectionsForNotes(
        [
          note('오늘', createdAt: date(2026, 8, 12, 9)),
          note('어제', createdAt: date(2026, 8, 11, 23)),
          note('사흘전', createdAt: date(2026, 8, 9, 1)),
        ],
        now: now,
      );

      expect(sections.map((s) => s.title), ['오늘', '어제', '3일 전']);
      expect(
        sections.map((s) => s.notes.map((n) => n.id).toList()),
        [
          ['오늘'],
          ['어제'],
          ['사흘전'],
        ],
      );
    });

    test('같은 날이면 자정을 사이에 두지 않는 한 한 섹션이다', () {
      final sections = grouper.sectionsForNotes(
        [
          note('늦은밤', createdAt: date(2026, 8, 12, 23, 59)),
          note('자정직후', createdAt: date(2026, 8, 12, 0, 0)),
        ],
        now: now,
      );

      expect(sections.length, 1);
      expect(sections[0].title, '오늘');
    });

    test('자정을 넘기면 1분 차이여도 다른 섹션이다', () {
      final sections = grouper.sectionsForNotes(
        [
          note('오늘00:00', createdAt: date(2026, 8, 12, 0, 0)),
          note('어제23:59', createdAt: date(2026, 8, 11, 23, 59)),
        ],
        now: now,
      );

      expect(sections.map((s) => s.title), ['오늘', '어제']);
    });

    test('시간대는 주입한 오프셋을 따른다', () {
      // KST 2026-08-12 08:00 = UTC 2026-08-11 23:00.
      // 서울에서는 오늘, UTC에서는 어제여야 한다.
      final morningInSeoul = date(2026, 8, 12, 8);
      const utcGrouper = NoteDateGrouper(utcOffset: Duration.zero);

      expect(
        grouper
            .sectionsForNotes([note('a', createdAt: morningInSeoul)], now: now)[0]
            .title,
        '오늘',
      );
      expect(
        utcGrouper
            .sectionsForNotes([note('a', createdAt: morningInSeoul)], now: now)[0]
            .title,
        '어제',
      );
    });

    test('미래 시각은 오늘로 접는다', () {
      final sections = grouper.sectionsForNotes(
        [note('미래', createdAt: now.add(const Duration(days: 3)))],
        now: now,
      );

      expect(sections.map((s) => s.title), ['오늘']);
    });

    test('고정한 노트는 날짜와 무관하게 맨 위 한 섹션으로 모은다', () {
      final sections = grouper.sectionsForNotes(
        [
          note('고정-오래된', createdAt: date(2026, 1, 2), isPinned: true),
          note('오늘', createdAt: date(2026, 8, 12, 9)),
        ],
        now: now,
      );

      expect(sections.map((s) => s.title), ['고정', '오늘']);
      expect(sections[0].notes.map((n) => n.id), ['고정-오래된']);
    });

    test('섹션 id는 서로 다르다', () {
      final sections = grouper.sectionsForNotes(
        [
          note('고정', createdAt: now, isPinned: true),
          note('오늘', createdAt: now),
          note('어제', createdAt: date(2026, 8, 11)),
        ],
        now: now,
      );

      expect(sections.map((s) => s.id).toSet().length, sections.length);
    });
  });
}
