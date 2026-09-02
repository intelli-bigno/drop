/// drop_core `NotesStore`(순수 상태 전이)를 화면이 구독할 수 있게 감싼다.
///
/// 스토어는 Swift `@Observable`이 하던 알림을 하지 않으므로, 상태를 건드리는
/// 모든 경로가 여기를 지나며 `notifyListeners`를 낸다. 낙관 갱신은 스토어가
/// 첫 await 전에 동기로 반영하므로 **호출 직후 한 번, 완료 후 한 번** 알린다.
library;

import 'package:drop_core/drop_core.dart';
import 'package:flutter/foundation.dart';

class NotesController extends ChangeNotifier {
  final NotesStore store;

  NotesController(this.store);

  Future<void> load() => _tracked(store.load());

  // 필터·보기 상태

  void setViewMode(NoteViewMode mode) {
    store.viewMode = mode;
    // 남은 선택이 다음 뷰의 일괄 동작에 걸리면 엉뚱한 노트가 지워진다.
    store.clearSelection();
    notifyListeners();
  }

  /// 할일 필터를 다음 상태로 돌린다 (BRU-184). 데스크톱과 같은 3단 순환.
  void cycleTodoFilter() {
    store.todoFilter = store.todoFilter.next;
    notifyListeners();
  }

  /// 노트를 할일로 올리거나 일반 노트로 되돌린다 (BRU-184).
  Future<void> setType(String id, NoteType type) =>
      _tracked(store.setType(id, type));

  /// 할일의 완료를 뒤집는다 (BRU-184).
  Future<void> setCompleted(String id, {required bool completed}) =>
      _tracked(store.setCompleted(id, completed: completed));

  /// 상단 고정을 걸고 푼다 (BRU-207). 목록 행을 왼쪽으로 밀면 나오는 동작이
  /// 유일한 입구다 — 그 전까지 Flutter 앱에는 진입점이 하나도 없었다.
  Future<void> setPinned(String id, {required bool isPinned}) =>
      _tracked(store.setPinned(id, isPinned: isPinned));

  void setCategory(NoteCategory category) {
    store.category = category;
    notifyListeners();
  }

  /// 같은 태그를 다시 고르면 필터를 푼다 — iOS `NoteFilterBar`와 같은 규칙.
  void toggleTag(String tagId) {
    store.selectedTagId = store.selectedTagId == tagId ? null : tagId;
    notifyListeners();
  }

  void setSearchText(String text) {
    store.searchText = text;
    notifyListeners();
  }

  // 선택 모드

  void toggleSelection(String id) {
    store.toggleSelection(id);
    notifyListeners();
  }

  void clearSelection() {
    store.clearSelection();
    notifyListeners();
  }

  // 노트 변경

  Future<Note?> create({required String content, String? parentId}) async {
    final task = store.create(content: content, parentId: parentId);
    notifyListeners();
    final created = await task;
    notifyListeners();
    return created;
  }

  /// 컴포저의 "노트 편집" 저장 경로 (BRU-158). id는 그대로, 본문만 바뀐다.
  Future<void> update({required String id, required String content}) =>
      _tracked(store.update(id: id, content: content));

  Future<void> archive(String id) => _tracked(store.archive(id));
  Future<void> unarchive(String id) => _tracked(store.unarchive(id));
  Future<void> moveToTrash(String id) => _tracked(store.moveToTrash(id));
  Future<void> restore(String id) => _tracked(store.restore(id));
  Future<void> deletePermanently(String id) =>
      _tracked(store.deletePermanently(id));

  /// 일괄 동작 (SelectionActionBar). 스토어에 없는 조합은 iOS와 같은 방식으로
  /// — 선택 목록을 먼저 복사하고 하나씩 — 처리한다.
  Future<void> archiveSelected() => _forEachSelected(store.archive);
  Future<void> unarchiveSelected() => _forEachSelected(store.unarchive);
  Future<void> restoreSelected() => _forEachSelected(store.restore);
  Future<void> trashSelected() => _tracked(store.trashSelected());
  Future<void> deleteSelectedPermanently() =>
      _tracked(store.deleteSelectedPermanently());

  void dismissError() {
    store.dismissError();
    notifyListeners();
  }

  Future<void> _forEachSelected(Future<void> Function(String id) body) async {
    final targets = [...store.selectedIds];
    store.clearSelection();
    notifyListeners();
    for (final id in targets) {
      await body(id);
    }
    notifyListeners();
  }

  Future<void> _tracked(Future<void> task) async {
    notifyListeners();
    await task;
    notifyListeners();
  }

  /// 태그 필터 선택·해제 (iOS `store.selectedTagID = ...` 대응).
  void selectTag(String? tagId) {
    store.selectedTagId = tagId;
    notifyListeners();
  }
}
