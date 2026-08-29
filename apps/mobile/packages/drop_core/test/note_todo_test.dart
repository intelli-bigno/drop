import 'package:drop_core/drop_core.dart';
import 'package:test/test.dart';

/// 할일 타입과 완료 상태 (BRU-184).
///
/// 데스크톱 `lib/note-todo.ts`·`packages/shared/src/types.ts`와 **같은 계약**을
/// 지킨다. 두 앱이 같은 DB를 보는데 규칙이 갈리면, 한쪽에서 만든 상태를 다른 쪽이
/// 거부하는 일이 생긴다 — 특히 `type='note'`로 되돌릴 때 완료 시각을 지우지 않으면
/// DB CHECK(`notes_todo_state_consistent`)가 갱신을 통째로 거부한다.
void main() {
  Map<String, Object?> json({
    Object? type = 'note',
    Object? completedAt,
  }) =>
      {
        'id': 'n1',
        'display_id': 1,
        'content': '내용',
        'created_at': '2026-08-29T00:00:00.000Z',
        'updated_at': '2026-08-29T00:00:00.000Z',
        'source': 'desktop',
        'type': type,
        'completed_at': completedAt,
      };

  Note noteWith({NoteType type = NoteType.note, DateTime? completedAt}) =>
      Note.fromJson(json(
        type: type.name,
        completedAt: completedAt?.toIso8601String(),
      ));

  group('Note.fromJson — 타입과 완료', () {
    test('일반 노트는 type이 note이고 완료 시각이 없다', () {
      final note = Note.fromJson(json());
      expect(note.type, NoteType.note);
      expect(note.completedAt, isNull);
    });

    test('할일 노트의 type을 그대로 옮긴다', () {
      expect(Note.fromJson(json(type: 'todo')).type, NoteType.todo);
    });

    test('완료 시각을 DateTime으로 옮긴다', () {
      final note = Note.fromJson(
          json(type: 'todo', completedAt: '2026-08-29T10:30:00.000Z'));
      expect(note.completedAt, DateTime.parse('2026-08-29T10:30:00.000Z'));
    });

    // 백필 이전 행이나 아직 갱신되지 않은 RPC 응답이 섞여도 목록이 깨지면 안 된다.
    // DB 기본값과 같은 쪽으로 넘어뜨린다 — 데스크톱 noteRowToNote와 같은 규칙.
    test('type이 없으면 일반 노트로 본다', () {
      final missing = json()..remove('type');
      expect(Note.fromJson(missing).type, NoteType.note);
    });

    // NoteSource.unknown과 같은 판단 — 서버가 모르는 값을 보내도 목록 전체가
    // 깨지지 않아야 한다. 다만 타입은 폴백이 'note'다(할일로 오인하면 안 된다).
    test('모르는 type 값은 일반 노트로 본다', () {
      expect(Note.fromJson(json(type: 'reference')).type, NoteType.note);
    });
  });

  group('isTodo / isCompleted', () {
    test('type이 todo면 할일이다', () {
      expect(noteWith(type: NoteType.todo).isTodo, isTrue);
      expect(noteWith().isTodo, isFalse);
    });

    test('완료 시각이 있는 할일은 끝난 것이다', () {
      expect(
        noteWith(type: NoteType.todo, completedAt: DateTime.utc(2026, 8, 29))
            .isCompleted,
        isTrue,
      );
      expect(noteWith(type: NoteType.todo).isCompleted, isFalse);
    });

    // DB CHECK가 이 조합을 막지만, 제약이 한 겹 뚫려도 일반 노트에 취소선이
    // 그어지면 안 된다 — 데스크톱 isCompleted와 같은 이유.
    test('일반 노트는 완료 시각이 있어도 끝난 것이 아니다', () {
      final impossible =
          Note.fromJson(json(completedAt: '2026-08-29T10:30:00.000Z'));
      expect(impossible.isCompleted, isFalse);
    });
  });

  group('replacing — 상태 전이', () {
    final done =
        noteWith(type: NoteType.todo, completedAt: DateTime.utc(2026, 8, 29));

    test('할일로 올린다', () {
      expect(noteWith().replacing(type: NoteType.todo).type, NoteType.todo);
    });

    // 지우지 않으면 DB CHECK가 갱신 자체를 거부한다
    test('일반 노트로 되돌리면 완료 시각도 지운다', () {
      final reverted = done.replacing(type: NoteType.note);
      expect(reverted.type, NoteType.note);
      expect(reverted.completedAt, isNull);
    });

    test('할일로 유지하면 완료 시각은 보존된다', () {
      expect(done.replacing(type: NoteType.todo).completedAt, done.completedAt);
    });

    test('완료 시각만 비울 수 있다', () {
      expect(done.replacing(completedAt: null).completedAt, isNull);
      expect(done.replacing(completedAt: null).type, NoteType.todo);
    });

    test('인자를 생략하면 완료 시각이 그대로다', () {
      expect(done.replacing(content: '바뀐 본문').completedAt, done.completedAt);
    });
  });

  _todoFilterTests();

  group('countOpenTodos — 남은 할일 수', () {
    Note n(String id,
            {NoteType type = NoteType.note,
            DateTime? completedAt,
            String? parentId}) =>
        Note.fromJson({
          'id': id,
          'display_id': 1,
          'content': '',
          'parent_id': parentId,
          'created_at': '2026-08-29T00:00:00.000Z',
          'updated_at': '2026-08-29T00:00:00.000Z',
          'source': 'desktop',
          'type': type.name,
          'completed_at': completedAt?.toIso8601String(),
        });

    test('끝나지 않은 할일만 센다', () {
      final notes = [
        n('a', type: NoteType.todo),
        n('b', type: NoteType.todo, completedAt: DateTime.utc(2026, 8, 29)),
        n('c'),
      ];
      expect(countOpenTodos(notes), 1);
    });

    // 답글은 피드에서 줄로 서지 않는다 — 데스크톱 countOpenTodos와 같은 규칙
    test('답글은 세지 않는다', () {
      final notes = [
        n('root', type: NoteType.todo),
        n('reply', type: NoteType.todo, parentId: 'root'),
      ];
      expect(countOpenTodos(notes), 1);
    });
  });
}

// ============================================================
// 할일 필터 (BRU-184) — 데스크톱 TodoFilter와 같은 3단 순환
// ============================================================

void _todoFilterTests() {
  Note n(String id,
          {NoteType type = NoteType.note,
          DateTime? completedAt,
          String? parentId}) =>
      Note.fromJson({
        'id': id,
        'display_id': 1,
        'content': id,
        'parent_id': parentId,
        'created_at': '2026-08-29T00:00:00.000Z',
        'updated_at': '2026-08-29T00:00:00.000Z',
        'source': 'desktop',
        'type': type.name,
        'completed_at': completedAt?.toIso8601String(),
      });

  group('NotesStore.todoFilter (BRU-184)', () {
    late NotesStore store;

    setUp(() {
      store = NotesStore(repository: InMemoryNotesRepository());
      store.allNotes = [
        n('plain'),
        n('open', type: NoteType.todo),
        n('done', type: NoteType.todo, completedAt: DateTime.utc(2026, 8, 29)),
      ];
    });

    List<String> visible() => store.visibleNotes.map((x) => x.id).toList();

    test('기본은 아무것도 걸러내지 않는다', () {
      expect(store.todoFilter, TodoFilter.off);
      expect(visible(), ['plain', 'open', 'done']);
    });

    // 끝난 것을 빼지 않는 이유: 방금 끝낸 것이 눈앞에서 사라지면 무슨 일이
    // 일어났는지 알 수 없다. 목록에는 남기고 화면에서 흐리게 그린다.
    test('all은 할일만 남긴다 — 끝난 것도 포함', () {
      store.todoFilter = TodoFilter.all;
      expect(visible(), ['open', 'done']);
    });

    test('open은 아직 안 끝난 할일만 남긴다', () {
      store.todoFilter = TodoFilter.open;
      expect(visible(), ['open']);
    });

    test('다음 상태로 순환한다 — off → all → open → off', () {
      expect(TodoFilter.off.next, TodoFilter.all);
      expect(TodoFilter.all.next, TodoFilter.open);
      expect(TodoFilter.open.next, TodoFilter.off);
    });

    test('검색·태그 필터와 AND로 걸린다', () {
      store.allNotes = [...store.allNotes, n('openMatch', type: NoteType.todo)];
      store.todoFilter = TodoFilter.all;
      store.searchText = 'openMatch';
      expect(visible(), ['openMatch']);
    });
  });
}
