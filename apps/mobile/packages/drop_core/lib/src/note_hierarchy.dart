import 'note.dart';

/// 목록 화면의 한 줄. 노트 하나와 그 노트를 어떻게 그릴지가 함께 담긴다.
/// DropCore `NoteHierarchy.swift` 대응.
///
/// 답글을 그리려면 노트만으로는 부족하다 — 몇 단 들여쓸지, 맥락으로 끌어온 것인지,
/// 부모를 잃은 것인지를 화면이 알아야 한다. 그 판단을 화면에 두면 검증할 수 없어
/// 여기서 미리 정해 내려보낸다.
class NoteRow {
  final Note note;

  /// 들여쓰기 단수. 데이터상 깊이가 아니라 **그릴 깊이**다 (상한에서 멈춘다).
  final int depth;

  /// 필터·검색에 걸린 것이 아니라 자식의 맥락을 위해 끌어온 노트.
  final bool isContextOnly;

  /// 부모가 이 뷰에 없어 최상위로 올라온 답글. 독립 노트처럼 보이면 안 된다.
  final bool isOrphanedReply;

  String get id => note.id;

  const NoteRow({
    required this.note,
    required this.depth,
    this.isContextOnly = false,
    this.isOrphanedReply = false,
  });

  @override
  bool operator ==(Object other) =>
      other is NoteRow &&
      other.note == note &&
      other.depth == depth &&
      other.isContextOnly == isContextOnly &&
      other.isOrphanedReply == isOrphanedReply;

  @override
  int get hashCode => Object.hash(note, depth, isContextOnly, isOrphanedReply);
}

/// 평평한 노트 목록을 부모-자식으로 묶어 화면이 그대로 그릴 행 배열로 만든다.
///
/// 순수 함수로 떼어 두어 에뮬레이터 없이 검증한다 — 데스크톱은 이 로직이 화면
/// 컴포넌트(`NoteFeed.tsx`) 안에 있어 테스트가 없다. 같은 실수를 반복하지 않는다.
class NoteHierarchy {
  NoteHierarchy._();

  /// 화면이 그릴 기본 들여쓰기 상한. 좁은 화면에서 3단 이상 들여쓰면 본문 폭이 무너진다.
  static const defaultMaxIndentDepth = 2;

  /// - [visible]: 필터·검색까지 통과해 **실제로 보여야 하는** 노트. 순서가 최상위 노트의 순서가 된다.
  /// - [context]: 같은 뷰(활성/보관/휴지통)에 있는 노트 전부. 부모를 끌어올 후보다.
  ///   `visible`은 이 집합의 부분집합이어야 한다.
  /// - [maxIndentDepth]: 들여쓰기 상한.
  ///
  /// 규칙:
  /// 1. 보이는 답글의 부모는 필터에 걸리지 않아도 **끌어온다** — 그러지 않으면 답글이
  ///    최상위로 튀어 어느 노트에 달린 것인지 알 수 없어진다.
  /// 2. 부모가 이 뷰에 아예 없으면(보관·휴지통에 있거나 지워졌으면) 답글을 버리지 않고
  ///    최상위로 올리되 `isOrphanedReply`로 표시한다. 버리면 노트가 조용히 사라진다.
  /// 3. 형제 답글은 오래된 것부터 — 데스크톱(`NoteFeed.tsx`)과 같은 규칙이다.
  static List<NoteRow> rows({
    required List<Note> visible,
    required List<Note> context,
    int maxIndentDepth = defaultMaxIndentDepth,
  }) {
    if (visible.isEmpty) return const [];

    // 같은 노트가 두 번 들어와도 행은 한 번만 나야 한다.
    final contextById = <String, Note>{};
    final contextOrder = <String>[];
    for (final note in context) {
      if (!contextById.containsKey(note.id)) {
        contextById[note.id] = note;
        contextOrder.add(note.id);
      }
    }

    final visibleIds = <String>{};
    final visibleOrder = <String>[];
    for (final note in visible) {
      if (visibleIds.add(note.id)) {
        visibleOrder.add(note.id);
        // visible이 context에 없을 수도 있다(호출자가 다른 집합을 넘긴 경우).
        // 그래도 노트를 잃지 않도록 여기서 채워 넣는다.
        if (!contextById.containsKey(note.id)) {
          contextById[note.id] = note;
          contextOrder.add(note.id);
        }
      }
    }

    // 규칙 1 — 보이는 노트의 조상을 맥락으로 끌어온다.
    final included = {...visibleIds};
    for (final id in visibleOrder) {
      final seen = <String>{id};
      var current = contextById[id];
      while (true) {
        final parentId = current?.parentId;
        if (parentId == null) break;
        final parent = contextById[parentId];
        if (parent == null) break;
        // 망가진 데이터(자기 참조·순환)에서 멈추지 않으면 무한 루프가 된다.
        if (!seen.add(parent.id)) break;
        included.add(parent.id);
        current = parent;
      }
    }

    // 부모를 따라 올라가다 제자리로 돌아오는 노트(망가진 데이터)를 가려낸다.
    // 이것을 자식으로 붙이면 어느 뿌리에서도 닿지 못해 목록에서 조용히 사라진다.
    final loops = <String>{};
    for (final id in contextOrder) {
      if (!included.contains(id)) continue;
      final seen = <String>{id};
      var current = contextById[id];
      while (true) {
        final parentId = current?.parentId;
        if (parentId == null || !included.contains(parentId)) break;
        final parent = contextById[parentId];
        if (parent == null) break;
        if (!seen.add(parent.id)) {
          loops.add(id);
          break;
        }
        current = parent;
      }
    }

    final childrenByParentId = <String, List<Note>>{};
    final rootIds = <String>[];
    for (final id in contextOrder) {
      if (!included.contains(id)) continue;
      final note = contextById[id];
      if (note == null) continue;
      final parentId = note.parentId;
      if (parentId != null &&
          !loops.contains(id) &&
          included.contains(parentId)) {
        childrenByParentId.putIfAbsent(parentId, () => []).add(note);
      } else {
        rootIds.add(id);
      }
    }

    // 규칙 3 — 형제는 오래된 것부터.
    for (final children in childrenByParentId.values) {
      children.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }

    final emitted = <String>{};
    final result = <NoteRow>[];

    void emit(Note note, int depth) {
      if (!emitted.add(note.id)) return;
      result.add(NoteRow(
        note: note,
        depth: depth < maxIndentDepth ? depth : maxIndentDepth,
        isContextOnly: !visibleIds.contains(note.id),
        // 규칙 2 — 부모가 있는데 최상위로 나온 것은 부모를 잃은 답글이다.
        isOrphanedReply:
            depth == 0 && note.parentId != null && note.parentId != note.id,
      ));
      for (final child in childrenByParentId[note.id] ?? const <Note>[]) {
        emit(child, depth + 1);
      }
    }

    for (final id in rootIds) {
      final note = contextById[id];
      if (note == null) continue;
      emit(note, 0);
    }

    return result;
  }
}
