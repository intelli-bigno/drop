import 'package:drop_core/drop_core.dart';
import 'package:test/test.dart';

import 'support/async_gate.dart';

/// DropCore `CommentsStoreTests.swift` 포팅.
/// 댓글은 노트가 아니다 — 목록·검색·위젯이 보는 `NotesStore`와 완전히 분리된
/// 자기 상태를 가진다. 여기서 검증하는 것은 그 상태의 규칙이다.
void main() {
  (CommentsStore, InMemoryCommentsRepository) makeStore(
      [List<NoteComment> comments = const []]) {
    final repository = InMemoryCommentsRepository(comments: comments);
    return (CommentsStore(repository: repository), repository);
  }

  NoteComment comment(
    String id, {
    String noteId = 'note-1',
    String body = '댓글',
    int created = 0,
  }) =>
      NoteComment(
        id: id,
        noteId: noteId,
        body: body,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (1700000000 + created) * 1000,
            isUtc: true),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
            (1700000000 + created) * 1000,
            isUtc: true),
      );

  group('노트 댓글 상태', () {
    // 로드

    /// 댓글은 대화다 — 오래된 것이 위, 새 것이 아래.
    test('불러오면 오래된 순으로 채워진다', () async {
      final (store, _) = makeStore([comment('b', created: 100), comment('a')]);

      await store.load('note-1');

      expect(store.commentsFor('note-1').map((c) => c.id), ['a', 'b']);
      expect(store.isLoading, isFalse);
    });

    test('다른 노트의 댓글은 섞이지 않는다', () async {
      final (store, _) =
          makeStore([comment('a'), comment('b', noteId: 'note-2')]);

      await store.load('note-1');

      expect(store.commentsFor('note-1').map((c) => c.id), ['a']);
      expect(store.commentsFor('note-2'), isEmpty);
    });

    test('첫 로드가 실패하면 오류를 노출한다', () async {
      final (store, repository) = makeStore();
      repository.loadError = const NotesRepositoryError.network('끊김');

      await store.load('note-1');

      expect(store.errorMessage, isNotNull);
      expect(store.commentsFor('note-1'), isEmpty);
    });

    /// BRU-51 규칙. 실패한 것은 "새 목록을 받아오는 일"이지 이미 받아 둔 목록이 아니다.
    test('다시 불러오기가 실패해도 보고 있던 댓글은 남는다', () async {
      final (store, repository) =
          makeStore([comment('a'), comment('b', created: 10)]);
      await store.load('note-1');

      repository.loadError = const NotesRepositoryError.network('끊김');
      await store.load('note-1');

      expect(store.errorMessage, isNotNull);
      expect(store.commentsFor('note-1').map((c) => c.id), ['a', 'b']);
    });

    /// (Swift의 CancellationError·URLError.cancelled 두 케이스가
    ///  Dart에서는 RequestCancelled 하나로 접힌다.)
    test('취소된 로드는 오류가 아니다', () async {
      final (store, repository) = makeStore([comment('a')]);
      await store.load('note-1');

      repository.loadError = const RequestCancelled();
      await store.load('note-1');

      expect(store.errorMessage, isNull);
      expect(store.commentsFor('note-1').map((c) => c.id), ['a']);
    });

    /// 화면 진입과 당겨서 새로고침이 겹칠 수 있다. 요청은 한 번만 보내되
    /// **먼저 도는 로드가 끝날 때까지 기다린다** (BRU-51, NotesStore.load()와 같은 규칙).
    test('로드 중에 다시 부르면 그 로드가 끝날 때까지 기다린다', () async {
      final (store, repository) = makeStore([comment('a')]);
      final gate = Gate();
      repository.beforeLoad = gate.wait;

      final first = store.load('note-1');
      while (!store.isLoading) {
        await pump(1);
      }

      var finished = false;
      final second = store.load('note-1').then((_) => finished = true);
      await pump(20);

      expect(finished, isFalse);

      gate.open();
      await first;
      await second;

      expect(finished, isTrue);
      expect(repository.loadCallCount, 1);
      expect(store.commentsFor('note-1').map((c) => c.id), ['a']);
    });

    /// 노트가 다르면 서로를 막지 않는다 — 겹침 방지는 같은 노트에 대해서만 건다.
    test('다른 노트의 로드는 서로를 기다리지 않는다', () async {
      final (store, repository) =
          makeStore([comment('a'), comment('b', noteId: 'note-2')]);
      final gate = Gate();
      repository.beforeLoad = gate.wait;

      final first = store.load('note-1');
      while (!store.isLoading) {
        await pump(1);
      }
      final second = store.load('note-2');
      await pump(20);

      gate.open();
      await first;
      await second;

      expect(repository.loadCallCount, 2);
    });

    // 개수 (뱃지)

    test('개수를 불러오면 노트별 뱃지 숫자가 채워진다', () async {
      final (store, _) = makeStore([
        comment('a'),
        comment('b', created: 10),
        comment('c', noteId: 'note-2'),
      ]);

      await store.loadCounts();

      expect(store.countFor('note-1'), 2);
      expect(store.countFor('note-2'), 1);
      // 댓글이 없는 노트는 0 — 화면은 0이면 뱃지를 그리지 않는다.
      expect(store.countFor('note-3'), 0);
    });

    test('개수 로드가 실패해도 이미 받아 둔 개수는 남는다', () async {
      final (store, repository) = makeStore([comment('a')]);
      await store.loadCounts();

      repository.loadError = const NotesRepositoryError.network('끊김');
      await store.loadCounts();

      expect(store.countFor('note-1'), 1);
      expect(store.errorMessage, isNotNull);
    });

    test('개수 로드 취소는 오류가 아니다', () async {
      final (store, repository) = makeStore([comment('a')]);
      await store.loadCounts();

      repository.loadError = const RequestCancelled();
      await store.loadCounts();

      expect(store.errorMessage, isNull);
      expect(store.countFor('note-1'), 1);
    });

    /// 목록을 열어 본 노트는 그 자리에서 개수가 맞춰져야 한다 —
    /// 뱃지와 실제 목록이 어긋나면 어느 쪽을 믿어야 할지 알 수 없다.
    test('목록을 불러오면 그 노트의 개수도 맞춰진다', () async {
      final (store, _) = makeStore([comment('a'), comment('b', created: 10)]);

      await store.load('note-1');

      expect(store.countFor('note-1'), 2);
    });

    // 작성

    test('쓴 댓글이 목록 끝에 즉시 나타난다', () async {
      final (store, _) = makeStore([comment('a')]);
      await store.load('note-1');

      await store.add(noteId: 'note-1', body: '새 댓글');

      expect(store.commentsFor('note-1').length, 2);
      expect(store.commentsFor('note-1').last.body, '새 댓글');
      expect(store.countFor('note-1'), 2);
    });

    test('작성이 실패하면 끼워 넣은 댓글을 되돌린다', () async {
      final (store, repository) = makeStore([comment('a')]);
      await store.load('note-1');
      repository.createError = const NotesRepositoryError.rejected('거절');

      await store.add(noteId: 'note-1', body: '새 댓글');

      expect(store.commentsFor('note-1').map((c) => c.id), ['a']);
      expect(store.countFor('note-1'), 1);
      expect(store.errorMessage, isNotNull);
    });

    /// DB가 `length(btrim(body)) > 0`을 요구한다. 서버까지 가서 거절당하지 말고
    /// 여기서 조용히 막는다 — 빈 입력은 오류가 아니라 아무 일도 아니다.
    test('공백뿐인 댓글은 보내지 않는다', () async {
      final (store, repository) = makeStore();
      await store.load('note-1');

      await store.add(noteId: 'note-1', body: '   \n ');

      expect(store.commentsFor('note-1'), isEmpty);
      expect(store.errorMessage, isNull);
      expect(repository.createCallCount, 0);
    });

    test('앞뒤 공백은 잘라서 보낸다', () async {
      final (store, repository) = makeStore();

      await store.add(noteId: 'note-1', body: '  다듬어짐  ');

      expect(repository.lastCreatedBody, '다듬어짐');
    });

    // 삭제

    /// 댓글은 소프트 삭제가 없다 — 지우면 바로 사라진다.
    test('삭제하면 목록과 개수에서 함께 빠진다', () async {
      final (store, _) = makeStore([comment('a'), comment('b', created: 10)]);
      await store.load('note-1');

      await store.delete(id: 'a', noteId: 'note-1');

      expect(store.commentsFor('note-1').map((c) => c.id), ['b']);
      expect(store.countFor('note-1'), 1);
    });

    test('삭제가 실패하면 댓글이 목록으로 돌아온다', () async {
      final (store, repository) =
          makeStore([comment('a'), comment('b', created: 10)]);
      await store.load('note-1');
      repository.mutationError = const NotesRepositoryError.network('끊김');

      await store.delete(id: 'a', noteId: 'note-1');

      expect(store.commentsFor('note-1').map((c) => c.id), ['a', 'b']);
      expect(store.countFor('note-1'), 2);
      expect(store.errorMessage, isNotNull);
    });

    test('오류는 확인하면 사라진다', () async {
      final (store, repository) = makeStore();
      repository.loadError = const NotesRepositoryError.network('끊김');
      await store.load('note-1');

      store.dismissError();

      expect(store.errorMessage, isNull);
    });
  });
}
