import 'package:drop_core/drop_core.dart';
import 'package:test/test.dart';

/// DropCore `NoteHierarchyTests.swift` 포팅.
/// 답글을 부모 아래로 묶는 순수 로직. 화면 없이 검증한다 (BRU-60).
void main() {
  DateTime date(int minute) =>
      DateTime.fromMillisecondsSinceEpoch((1770000000 + minute * 60) * 1000,
          isUtc: true);

  Note note(String id, {String? parent, int at = 0, bool isPinned = false}) =>
      Note(
        id: id,
        displayId: 0,
        content: id,
        parentId: parent,
        createdAt: date(at),
        updatedAt: date(at),
        source: NoteSource.mobile,
        isPinned: isPinned,
      );

  /// 화면이 실제로 넘기는 순서 — 최신 노트가 위다.
  List<NoteRow> rows(List<Note> notes,
          {List<Note>? context, int maxIndentDepth = 2}) =>
      NoteHierarchy.rows(
        visible: notes,
        context: context ?? notes,
        maxIndentDepth: maxIndentDepth,
      );

  group('노트 계층', () {
    test('빈 목록은 행도 없다', () {
      expect(rows([]), isEmpty);
    });

    test('답글은 부모 바로 아래에 한 단 들여쓴다', () {
      final parent = note('부모', at: 10);
      final reply = note('답글', parent: '부모', at: 20);

      final result = rows([reply, parent]);

      expect(result.map((r) => r.note.id), ['부모', '답글']);
      expect(result.map((r) => r.depth), [0, 1]);
    });

    test('형제 답글은 오래된 것부터 (데스크톱과 같은 규칙)', () {
      final result = rows([
        note('나중답글', parent: '부모', at: 30),
        note('먼저답글', parent: '부모', at: 20),
        note('부모', at: 10),
      ]);

      expect(result.map((r) => r.note.id), ['부모', '먼저답글', '나중답글']);
    });

    test('최상위 노트의 순서는 넘겨받은 순서를 그대로 지킨다', () {
      final result = rows([
        note('최신', at: 30),
        note('중간', at: 20),
        note('오래된', at: 10),
      ]);

      expect(result.map((r) => r.note.id), ['최신', '중간', '오래된']);
      expect(result.every((r) => r.depth == 0), isTrue);
    });

    test('손자까지 이어 붙인다 — 스레드가 통째로 붙어 있다', () {
      final result = rows([
        note('다른뿌리', at: 40),
        note('손자', parent: '답글', at: 30),
        note('답글', parent: '부모', at: 20),
        note('부모', at: 10),
      ]);

      expect(result.map((r) => r.note.id), ['다른뿌리', '부모', '답글', '손자']);
      expect(result.map((r) => r.depth), [0, 0, 1, 2]);
    });

    test('들여쓰기는 2단에서 멈춘다 — 좁은 화면에서 본문 폭이 무너지지 않게', () {
      final result = rows([
        note('증손자', parent: '손자', at: 40),
        note('손자', parent: '답글', at: 30),
        note('답글', parent: '부모', at: 20),
        note('부모', at: 10),
      ]);

      expect(result.map((r) => r.note.id), ['부모', '답글', '손자', '증손자']);
      // 데이터상 깊이는 3이지만 들여쓰기는 2에서 멈춘다.
      expect(result.map((r) => r.depth), [0, 1, 2, 2]);
    });

    // 필터·검색에서 부모가 빠졌을 때

    test('검색에 답글만 걸려도 부모를 끌어와 답글이 최상위로 튀지 않는다', () {
      final parent = note('부모', at: 10);
      final reply = note('답글', parent: '부모', at: 20);

      // 검색어가 답글에만 걸린 상황
      final result = rows([reply], context: [parent, reply]);

      expect(result.map((r) => r.note.id), ['부모', '답글']);
      expect(result.map((r) => r.depth), [0, 1]);
      // 맥락으로 끌어온 부모는 그렇게 표시된다 — 검색 결과인 척하지 않는다.
      expect(result.map((r) => r.isContextOnly), [true, false]);
    });

    test('끌어온 부모가 또 답글이면 그 위까지 이어 올라간다', () {
      final result = rows(
        [note('손자', parent: '답글', at: 30)],
        context: [
          note('부모', at: 10),
          note('답글', parent: '부모', at: 20),
          note('손자', parent: '답글', at: 30),
        ],
      );

      expect(result.map((r) => r.note.id), ['부모', '답글', '손자']);
      expect(result.map((r) => r.isContextOnly), [true, true, false]);
    });

    test('부모가 다른 뷰에 있으면(보관·휴지통) 답글을 버리지 않고 최상위로 올리되 표시한다', () {
      // 부모는 보관함에 있어 이 뷰의 context에 아예 없다.
      final orphan = note('답글', parent: '사라진부모', at: 20);

      final result = rows([orphan]);

      expect(result.map((r) => r.note.id), ['답글']);
      expect(result.map((r) => r.depth), [0]);
      // 독립 노트인 척하면 맥락이 사라진다 — 화면이 "답글"이라고 표시할 수 있게 알린다.
      expect(result.map((r) => r.isOrphanedReply), [true]);
    });

    test('맥락으로 끌어온 부모는 자기 자식 중 걸린 것만 데려온다', () {
      final parent = note('부모', at: 10);
      final matched = note('걸린답글', parent: '부모', at: 20);
      final unmatched = note('안걸린답글', parent: '부모', at: 30);

      final result = rows([matched], context: [parent, matched, unmatched]);

      expect(result.map((r) => r.note.id), ['부모', '걸린답글']);
    });

    test('부모가 자기 자신을 가리키는 망가진 데이터에도 멈추지 않는다', () {
      final result = rows([note('고리', parent: '고리', at: 10)]);

      expect(result.map((r) => r.note.id), ['고리']);
      expect(result.map((r) => r.depth), [0]);
    });

    test('두 노트가 서로를 가리켜도 멈추지 않는다', () {
      final result =
          rows([note('가', parent: '나', at: 10), note('나', parent: '가', at: 20)]);

      expect(result.map((r) => r.note.id).toSet(), {'가', '나'});
    });

    test('같은 노트가 두 번 들어와도 행은 한 번만 난다', () {
      final duplicated = note('부모', at: 10);

      final result = rows([duplicated, duplicated]);

      expect(result.map((r) => r.note.id), ['부모']);
    });
  });
}
