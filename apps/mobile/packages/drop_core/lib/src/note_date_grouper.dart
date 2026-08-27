import 'note.dart';
import 'note_hierarchy.dart';

/// 목록 화면의 한 섹션. 화면은 이 배열을 그대로 그리기만 한다.
/// DropCore `NoteDateGrouper.swift` 대응.
class NoteSection {
  final String id;
  final String title;

  /// 들여쓰기까지 정해진 행. 화면은 이 순서대로 그린다.
  final List<NoteRow> rows;

  /// 계층을 보지 않는 쪽(위젯·미리보기 등)을 위한 평평한 시선.
  List<Note> get notes => rows.map((row) => row.note).toList();

  const NoteSection({required this.id, required this.title, required this.rows});

  NoteSection.fromNotes({
    required this.id,
    required this.title,
    required List<Note> notes,
  }) : rows = notes.map((note) => NoteRow(note: note, depth: 0)).toList();
}

/// 정렬된 노트 목록을 날짜 섹션으로 묶는다.
///
/// 순수 함수로 떼어 두어 에뮬레이터 없이 검증한다 — 자정·시간대 경계가
/// 화면 코드 안에 숨어 있으면 검증할 방법이 없다.
///
/// Swift 판은 `Calendar`를 주입받는다. 순수 Dart에는 시간대 달력이 없어
/// **UTC 오프셋**을 주입받는 것으로 같은 계약(주입한 시간대를 따른다)을 지킨다.
/// 넘기지 않으면 기기 로컬 시간대를 쓴다.
class NoteDateGrouper {
  final Duration? utcOffset;

  const NoteDateGrouper({this.utcOffset});

  DateTime _localDay(DateTime date) {
    final offset = utcOffset;
    final local =
        offset == null ? date.toLocal() : date.toUtc().add(offset);
    return DateTime.utc(local.year, local.month, local.day);
  }

  List<NoteSection> sectionsForNotes(List<Note> notes, {DateTime? now}) =>
      sections(
        notes.map((note) => NoteRow(note: note, depth: 0)).toList(),
        now: now,
      );

  /// 입력 순서를 그대로 유지한다 — 정렬은 `NoteAssembler.sorted`의 몫이고,
  /// 여기서 다시 정렬하면 두 규칙이 어긋날 때 화면이 조용히 달라진다.
  ///
  /// 스레드는 통째로 한 섹션에 들어간다 — 답글은 자기 날짜가 아니라 **뿌리 노트의**
  /// 날짜를 따른다. 자기 날짜로 나누면 스레드가 날짜 경계에서 쪼개져,
  /// 계층으로 묶은 이유(맥락 유지)가 사라진다.
  ///
  /// 고정한 노트는 날짜와 무관하게 맨 위로 뜨므로(정렬 규칙) 날짜에 섞지 않고
  /// 따로 한 섹션으로 모은다.
  List<NoteSection> sections(List<NoteRow> rows, {DateTime? now}) {
    final sections = <NoteSection>[];
    final reference = now ?? DateTime.now();

    // depth 0에서 시작해 다음 depth 0 직전까지가 스레드 하나다.
    final threads = <List<NoteRow>>[];
    for (final row in rows) {
      if (row.depth == 0 || threads.isEmpty) {
        threads.add([row]);
      } else {
        threads.last.add(row);
      }
    }

    final pinned =
        threads.where((thread) => thread.first.note.isPinned).toList();
    if (pinned.isNotEmpty) {
      sections.add(NoteSection(
        id: 'pinned',
        title: '고정',
        rows: pinned.expand((thread) => thread).toList(),
      ));
    }

    final today = _localDay(reference);
    final order = <DateTime>[];
    final byDay = <DateTime, List<NoteRow>>{};

    for (final thread in threads) {
      if (thread.first.note.isPinned) continue;
      // 미래 시각(기기 시계 어긋남 등)은 오늘로 접는다. relativeTimeString이
      // 미래를 "0초전"으로 접는 것과 같은 태도다.
      var day = _localDay(thread.first.note.createdAt);
      if (day.isAfter(today)) day = today;
      if (!byDay.containsKey(day)) order.add(day);
      byDay.putIfAbsent(day, () => []).addAll(thread);
    }

    for (final day in order) {
      sections.add(NoteSection(
        id: 'day-${day.millisecondsSinceEpoch ~/ 1000}',
        title: _title(day, today),
        rows: byDay[day] ?? const [],
      ));
    }

    return sections;
  }

  String _title(DateTime day, DateTime today) {
    final days = today.difference(day).inDays;
    if (days < 1) return '오늘';
    if (days == 1) return '어제';
    return '$days일 전';
  }
}
