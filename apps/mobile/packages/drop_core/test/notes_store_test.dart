import 'package:drop_core/drop_core.dart';
import 'package:test/test.dart';

import 'support/async_gate.dart';

/// DropCore `NotesStoreTests.swift` 포팅.
/// Riverpod의 notesProvider + selection_provider + 필터 상태를 하나로 합친 것.
void main() {
  (NotesStore, InMemoryNotesRepository) makeStore([List<Note> notes = const []]) {
    final repository = InMemoryNotesRepository(notes: notes);
    return (NotesStore(repository: repository), repository);
  }

  Note note(
    String id, {
    String content = '',
    int created = 0,
    bool archived = false,
    bool trashed = false,
    bool pinned = false,
    bool hasLink = false,
    List<String> tags = const [],
  }) =>
      Note(
        id: id,
        displayId: 1,
        content: content,
        tags: tags
            .map((t) => Tag(id: t, name: t, createdAt: DateTime.utc(1970)))
            .toList(),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (1700000000 + created) * 1000,
            isUtc: true),
        updatedAt: DateTime.utc(1970),
        source: NoteSource.mobile,
        archivedAt: archived ? DateTime.utc(1970) : null,
        deletedAt: trashed ? DateTime.utc(1970) : null,
        hasLink: hasLink,
        isPinned: pinned,
      );

  Note reply(String id, {required String to, int created = 0}) => Note(
        id: id,
        displayId: 1,
        content: id,
        parentId: to,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (1700000000 + created) * 1000,
            isUtc: true),
        updatedAt: DateTime.utc(1970),
        source: NoteSource.mobile,
      );

  group('노트 목록 상태', () {
    test('답글을 만들면 부모 아래에 붙는다', () async {
      final (store, _) = makeStore([note('부모', created: 10)]);
      await store.load();

      await store.create(content: '답글 본문', parentId: '부모');

      expect(store.visibleRows.map((r) => r.note.content), ['', '답글 본문']);
      expect(store.visibleRows.map((r) => r.depth), [0, 1]);
    });

    /// 저장을 기다리기 전에 끼워 넣는 placeholder에 parentId가 없으면
    /// 답글이 최상위에 잠깐 떴다가 저장 후 부모 아래로 점프한다.
    test('저장 전 낙관적으로 끼워 넣은 답글도 곧장 부모 아래에 붙는다', () async {
      final (store, repository) = makeStore([note('부모', created: 10)]);
      await store.load();

      // 저장이 끝나기 전 상태를 보기 위해 리포지토리를 막아 둔다.
      final gate = Gate();
      repository.beforeCreate = gate.wait;

      final creating = store.create(content: '답글', parentId: '부모');
      await pump(2);

      expect(store.visibleRows.map((r) => r.depth), [0, 1]);

      gate.open();
      await creating;
    });

    test('답글 저장이 실패하면 끼워 넣었던 답글을 걷어낸다', () async {
      final (store, repository) = makeStore([note('부모', created: 10)]);
      await store.load();
      repository.createError = const NotesRepositoryError.network('끊김');

      await store.create(content: '답글', parentId: '부모');

      expect(store.visibleRows.map((r) => r.depth), [0]);
      expect(store.errorMessage, isNotNull);
    });

    test('부모를 넘기지 않으면 종전처럼 최상위 노트가 된다', () async {
      final (store, _) = makeStore();
      await store.load();

      await store.create(content: '혼자 쓰는 노트');

      expect(store.visibleRows.map((r) => r.depth), [0]);
      expect(store.visibleRows.first.note.parentId, isNull);
    });

    // 계층 (BRU-60)

    test('답글은 부모 아래 한 단 들여쓴 행으로 나온다', () async {
      final (store, _) =
          makeStore([note('부모', created: 10), reply('답글', to: '부모', created: 20)]);

      await store.load();

      expect(store.visibleRows.map((r) => r.note.id), ['부모', '답글']);
      expect(store.visibleRows.map((r) => r.depth), [0, 1]);
    });

    test('검색이 답글에만 걸려도 부모를 맥락으로 끌어와 계층을 지킨다', () async {
      final (store, _) = makeStore([
        note('부모', content: '장보기', created: 10),
        reply('답글', to: '부모', created: 20),
      ]);

      await store.load();
      store.searchText = '답글';

      expect(store.visibleNotes.map((n) => n.id), ['답글']);
      expect(store.visibleRows.map((r) => r.note.id), ['부모', '답글']);
      expect(store.visibleRows.map((r) => r.isContextOnly), [true, false]);
    });

    /// 보관함에 있는 부모를 활성 목록으로 끌어오면 치운 노트가 되살아난다.
    /// 답글은 버리지 않되 최상위로 올리고, 화면이 알아볼 수 있게 표시한다.
    test('부모가 보관함에 있으면 끌어오지 않고 답글만 최상위로 올린다', () async {
      final (store, _) = makeStore([
        note('부모', created: 10, archived: true),
        reply('답글', to: '부모', created: 20),
      ]);

      await store.load();

      expect(store.visibleRows.map((r) => r.note.id), ['답글']);
      expect(store.visibleRows.map((r) => r.depth), [0]);
      expect(store.visibleRows.map((r) => r.isOrphanedReply), [true]);
    });

    test('보관 탭에서도 부모-자식이 묶인다', () async {
      final archivedReply = Note(
        id: '답글',
        displayId: 1,
        content: '답글',
        parentId: '부모',
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(1700000020 * 1000, isUtc: true),
        updatedAt: DateTime.utc(1970),
        source: NoteSource.mobile,
        archivedAt: DateTime.utc(1970),
      );
      final (store, _) =
          makeStore([note('부모', created: 10, archived: true), archivedReply]);

      await store.load();
      store.viewMode = NoteViewMode.archived;

      expect(store.visibleRows.map((r) => r.note.id), ['부모', '답글']);
      expect(store.visibleRows.map((r) => r.depth), [0, 1]);
    });

    test('불러오면 목록이 채워진다', () async {
      final (store, _) = makeStore([note('a'), note('b')]);

      await store.load();

      expect(store.visibleNotes.length, 2);
      expect(store.isLoading, isFalse);
    });

    test('첫 로드가 실패하면 오류를 노출한다', () async {
      final (store, repository) = makeStore();
      repository.loadError = const NotesRepositoryError.network('끊김');

      await store.load();

      expect(store.errorMessage, isNotNull);
      expect(store.visibleNotes, isEmpty);
    });

    /// 당겨서 새로고침이 실패했다고 보고 있던 노트까지 사라지면 안 된다.
    /// (BRU-51 — 새로고침 한 번 실패에 화면이 통째로 비어 버리던 문제)
    test('새로고침이 실패해도 보고 있던 목록은 남는다', () async {
      final (store, repository) = makeStore([note('a'), note('b')]);
      await store.load();

      repository.loadError = const NotesRepositoryError.network('끊김');
      await store.load();

      expect(store.errorMessage, isNotNull);
      expect(store.visibleNotes.map((n) => n.id), ['a', 'b']);
    });

    /// 당겨서 새로고침은 손을 떼는 순간 취소된다. 취소는 장애가 아니므로
    /// 오류창을 띄우지도, 이미 보고 있던 목록을 지우지도 않아야 한다.
    /// (Swift의 CancellationError·URLError.cancelled 두 케이스가
    ///  Dart에서는 RequestCancelled 하나로 접힌다.)
    test('취소된 로드는 오류가 아니다', () async {
      final (store, repository) = makeStore([note('a'), note('b')]);
      await store.load();

      repository.loadError = const RequestCancelled();
      await store.load();

      expect(store.errorMessage, isNull);
      expect(store.visibleNotes.length, 2);
    });

    /// 화면에 들어오면서 도는 첫 로드와 당겨서 새로고침이 겹칠 수 있다.
    /// 둘 다 서버까지 가면 늦게 끝난 쪽이 목록을 덮어써 방금 본 화면이 되돌아간다.
    test('이미 로드 중이면 다시 로드하지 않는다', () async {
      final (store, repository) = makeStore([note('a')]);
      final gate = Gate();
      repository.beforeLoad = gate.wait;

      final first = store.load();
      while (!store.isLoading) {
        await pump(1);
      }

      final second = store.load();
      // 두 번째 호출이 리포지토리까지 갈 틈을 준다 — 막히지 않았다면 여기서 센다.
      await pump(2);
      gate.open();
      await first;
      await second;

      expect(repository.loadCallCount, 1);
    });

    /// 겹친 호출이 요청을 한 번만 보내는 것과, 요청을 아예 건너뛰고 즉시 끝나는 것은
    /// 다르다. 당겨서 새로고침은 호출이 끝나는 순간 스피너를 접으므로,
    /// 즉시 돌아오면 아무 일도 하지 않은 채 스피너만 튕기고 만다 (BRU-51).
    test('로드 중에 당긴 새로고침은 그 로드가 끝날 때까지 기다린다', () async {
      final (store, repository) = makeStore([note('a')]);
      final gate = Gate();
      repository.beforeLoad = gate.wait;

      final first = store.load();
      while (!store.isLoading) {
        await pump(1);
      }

      var finished = false;
      final refresh = store.load().then((_) => finished = true);
      await pump(20);

      // 진행 중인 로드가 아직 서버에 매달려 있는데 새로고침이 끝나 있으면 안 된다.
      expect(finished, isFalse);

      gate.open();
      await first;
      await refresh;

      expect(finished, isTrue);
      expect(repository.loadCallCount, 1);
      expect(store.visibleNotes.map((n) => n.id), ['a']);
    });

    /// 보관·휴지통 노트도 함께 받아 화면에서 거른다 (두 네이티브 앱과 같은 구조).
    test('뷰 모드가 목록을 가른다', () async {
      final (store, _) = makeStore(
          [note('활성'), note('보관', archived: true), note('휴지통', trashed: true)]);
      await store.load();

      expect(store.visibleNotes.map((n) => n.id), ['활성']);

      store.viewMode = NoteViewMode.archived;
      expect(store.visibleNotes.map((n) => n.id), ['보관']);

      store.viewMode = NoteViewMode.trash;
      expect(store.visibleNotes.map((n) => n.id), ['휴지통']);
    });

    test('카테고리 필터가 함께 걸린다', () async {
      final (store, _) = makeStore([note('링크', hasLink: true), note('보통')]);
      await store.load();

      store.category = NoteCategory.links;

      expect(store.visibleNotes.map((n) => n.id), ['링크']);
    });

    test('태그 필터는 선택한 태그를 가진 노트만 남긴다', () async {
      final (store, _) =
          makeStore([note('일', tags: ['work']), note('잡', tags: ['etc'])]);
      await store.load();

      store.selectedTagId = 'work';

      expect(store.visibleNotes.map((n) => n.id), ['일']);
    });

    test('검색어는 본문에 걸린다', () async {
      final (store, _) =
          makeStore([note('a', content: '회의 준비'), note('b', content: '장보기')]);
      await store.load();

      store.searchText = '회의';

      expect(store.visibleNotes.map((n) => n.id), ['a']);
    });

    /// 새 노트는 저장을 기다리지 않고 목록에 먼저 들어간다.
    test('작성한 노트가 목록 맨 앞에 즉시 나타난다', () async {
      final (store, _) = makeStore([note('기존', created: 0)]);
      await store.load();

      await store.create(content: '새 노트');

      expect(store.visibleNotes.first.content, '새 노트');
      expect(store.visibleNotes.length, 2);
    });

    /// 첨부(카메라·갤러리·공유함)는 "방금 만든 노트"에 붙여야 한다. 목록에서
    /// 되찾으면 정렬 1순위인 고정 노트가 늘 맨 앞이라 **엉뚱한 노트에 붙는다**
    /// (BRU-43). 그래서 `create`가 만들어진 노트를 직접 돌려준다.
    test('작성한 노트를 돌려준다 — 고정 노트가 있어도 그 노트가 아니다', () async {
      final (store, _) = makeStore([note('고정', created: 0, pinned: true)]);
      await store.load();

      final created = await store.create(content: '새 노트');

      expect(created?.content, '새 노트');
      expect(created?.id, isNot('고정'));
      // 고정 노트가 맨 앞이므로 목록 첫 줄로 되찾으면 틀린 노트를 잡는다.
      expect(store.visibleNotes.first.id, '고정');
      expect(store.allNotes.any((n) => n.id == created?.id), isTrue);
    });

    /// 위젯 카메라 바로가기는 **필터가 켜진 채** 눌리기 쉽다. 그때 빈 노트는
    /// `visibleNotes`에서 아예 걸러지므로 목록에서는 되찾을 길이 없다.
    test('태그 필터가 켜져 있어도 방금 만든 노트를 돌려준다', () async {
      final (store, _) = makeStore([note('태그있음', tags: ['일'])]);
      await store.load();
      store.selectedTagId = '일';

      final created = await store.create(content: '');

      expect(created, isNotNull);
      // 빈 노트는 태그가 없어 목록에서 걸러진다 — 되찾기는 불가능하다.
      expect(store.visibleNotes.any((n) => n.id == created?.id), isFalse);
    });

    /// 저장이 실패했으면 붙일 노트가 없다. null을 돌려줘야 호출부가
    /// 첨부 업로드를 건너뛴다.
    test('작성이 실패하면 아무 노트도 돌려주지 않는다', () async {
      final (store, repository) = makeStore();
      await store.load();
      repository.createError = const NotesRepositoryError.rejected('거절');

      final created = await store.create(content: '새 노트');

      expect(created, isNull);
    });

    /// 실패하면 끼워 넣은 노트를 걷어내야 한다. 안 그러면 새로고침 전까지
    /// 저장되지도 않은 노트가 목록에 남아 있게 된다.
    test('작성이 실패하면 끼워 넣은 노트를 되돌린다', () async {
      final (store, repository) = makeStore([note('기존')]);
      await store.load();
      repository.createError = const NotesRepositoryError.rejected('거절');

      await store.create(content: '새 노트');

      expect(store.visibleNotes.map((n) => n.id), ['기존']);
      expect(store.errorMessage, isNotNull);
    });

    test('휴지통으로 보내면 활성 목록에서 사라진다', () async {
      final (store, _) = makeStore([note('a'), note('b')]);
      await store.load();

      await store.moveToTrash('a');

      expect(store.visibleNotes.map((n) => n.id), ['b']);
    });

    /// Rule B (BRU-115): 복원은 받은편지함으로 되돌리기다.
    test('보관한 노트를 휴지통에 넣었다 복원하면 활성 목록으로 온다', () async {
      final (store, _) = makeStore([note('a', archived: true)]);
      await store.load();

      await store.moveToTrash('a');
      store.viewMode = NoteViewMode.trash;
      expect(store.visibleNotes.map((n) => n.id), ['a']);

      await store.restore('a');

      store.viewMode = NoteViewMode.active;
      expect(store.visibleNotes.map((n) => n.id), ['a']);
      store.viewMode = NoteViewMode.archived;
      expect(store.visibleNotes, isEmpty);
    });

    /// 예전 데스크톱이 archived_at을 남긴 이중 플래그 행도 복원하면 활성이다.
    test('휴지통에 남은 보관 흔적도 복원하면 지워진다', () async {
      final (store, _) = makeStore([note('a', archived: true, trashed: true)]);
      await store.load();

      await store.restore('a');

      store.viewMode = NoteViewMode.active;
      expect(store.visibleNotes.map((n) => n.id), ['a']);
      store.viewMode = NoteViewMode.archived;
      expect(store.visibleNotes, isEmpty);
    });

    test('삭제가 실패하면 노트가 목록으로 돌아온다', () async {
      final (store, repository) = makeStore([note('a')]);
      await store.load();
      repository.mutationError = const NotesRepositoryError.network('끊김');

      await store.moveToTrash('a');

      expect(store.visibleNotes.map((n) => n.id), ['a']);
      expect(store.errorMessage, isNotNull);
    });

    test('선택 모드에서 여러 노트를 골라 한 번에 버린다', () async {
      final (store, _) = makeStore([note('a'), note('b'), note('c')]);
      await store.load();

      store.toggleSelection('a');
      store.toggleSelection('c');
      expect(store.selectedIds, {'a', 'c'});

      await store.trashSelected();

      expect(store.visibleNotes.map((n) => n.id), ['b']);
      // 일괄 처리가 끝나면 선택 모드에서 빠져나와야 한다 —
      // 선택이 남아 있으면 다음 탭이 엉뚱한 노트에 걸린다.
      expect(store.selectedIds, isEmpty);
      expect(store.isSelecting, isFalse);
    });

    test('선택을 다시 누르면 해제된다', () async {
      final (store, _) = makeStore([note('a')]);
      await store.load();

      store.toggleSelection('a');
      store.toggleSelection('a');

      expect(store.selectedIds, isEmpty);
      expect(store.isSelecting, isFalse);
    });

    test('고정하면 목록 맨 위로 올라간다', () async {
      final (store, _) = makeStore([note('a', created: 100), note('b', created: 0)]);
      await store.load();

      await store.setPinned('b', isPinned: true);

      expect(store.visibleNotes.map((n) => n.id), ['b', 'a']);
    });

    test('본문을 고치면 목록에 바로 반영된다', () async {
      final (store, _) = makeStore([note('a', content: '예전')]);
      await store.load();

      await store.update(id: 'a', content: '새 내용');

      expect(store.visibleNotes.first.content, '새 내용');
    });
  });
}
