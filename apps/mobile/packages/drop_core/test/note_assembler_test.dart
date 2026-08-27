import 'package:drop_core/drop_core.dart';
import 'package:test/test.dart';

/// DropCore `NoteAssemblerTests.swift` 포팅.
/// 목록 조회는 notes / attachments / note_tags 세 번의 쿼리 결과를 합쳐 만든다.
/// 합치는 규칙만 떼어내면 네트워크 없이 검증할 수 있다 — 실제 버그가 나는 곳도 여기다.
void main() {
  final now = DateTime.fromMillisecondsSinceEpoch(1770000000 * 1000, isUtc: true);

  Note note(String id,
          {bool pinned = false, DateTime? pinnedAt, int created = 0}) =>
      Note(
        id: id,
        displayId: 1,
        content: '',
        createdAt: now.add(Duration(seconds: created)),
        updatedAt: now,
        source: NoteSource.mobile,
        isPinned: pinned,
        pinnedAt: pinnedAt,
      );

  Attachment attachment(String id, {required String noteId}) => Attachment(
        id: id,
        noteId: noteId,
        type: AttachmentType.image,
        storagePath: 'p/$id',
        createdAt: now,
      );

  Tag tag(String id, String name) => Tag(id: id, name: name, createdAt: now);

  group('노트 조립', () {
    test('첨부와 태그를 노트별로 붙인다', () {
      final assembled = NoteAssembler.assemble(
        notes: [note('n1'), note('n2')],
        attachments: [
          attachment('a1', noteId: 'n1'),
          attachment('a2', noteId: 'n1'),
        ],
        tagsByNoteId: {
          'n2': [tag('t1', '일')],
        },
      );

      expect(assembled[0].attachments.map((a) => a.id), ['a1', 'a2']);
      expect(assembled[0].tags, isEmpty);
      expect(assembled[1].attachments, isEmpty);
      expect(assembled[1].tags.map((t) => t.name), ['일']);
    });

    /// 삭제된 노트의 첨부가 뒤늦게 딸려오는 경우가 있다. 주인 없는 첨부는 버린다.
    test('주인이 없는 첨부는 버린다', () {
      final assembled = NoteAssembler.assemble(
        notes: [note('n1')],
        attachments: [
          attachment('a1', noteId: 'n1'),
          attachment('a9', noteId: '없는노트'),
        ],
        tagsByNoteId: const {},
      );

      expect(assembled.length, 1);
      expect(assembled[0].attachments.map((a) => a.id), ['a1']);
    });

    test('입력 순서를 그대로 유지한다', () {
      final assembled = NoteAssembler.assemble(
        notes: [note('c'), note('a'), note('b')],
        attachments: const [],
        tagsByNoteId: const {},
      );

      expect(assembled.map((n) => n.id), ['c', 'a', 'b']);
    });

    /// 정렬 규칙: 고정 먼저 → 고정 시각 최신순 → 생성 시각 최신순.
    test('고정된 노트가 위로, 그 안에서는 최신순', () {
      final old = note('old', created: -100);
      final recent = note('new', created: 100);
      final pinnedEarlier = note('p1',
          pinned: true, pinnedAt: now.subtract(const Duration(seconds: 50)));
      final pinnedLater = note('p2', pinned: true, pinnedAt: now);

      final sorted =
          NoteAssembler.sorted([old, recent, pinnedEarlier, pinnedLater]);

      expect(sorted.map((n) => n.id), ['p2', 'p1', 'new', 'old']);
    });

    /// 고정 시각이 없는 오래된 데이터가 섞여 있어도 정렬이 무너지면 안 된다.
    test('고정 시각이 없는 고정 노트도 고정 묶음에 남는다', () {
      final pinnedNoDate = note('p0', pinned: true);
      final plain = note('n', created: 1000);

      final sorted = NoteAssembler.sorted([plain, pinnedNoDate]);

      expect(sorted.map((n) => n.id), ['p0', 'n']);
    });
  });
}
