/// drop_core `CommentsStore`를 화면이 구독할 수 있게 감싼다.
/// 홈 목록은 뱃지 숫자만 쓰고, 목록·작성·삭제는 뷰어의 댓글 시트(BRU-157)가 쓴다.
library;

import 'package:drop_core/drop_core.dart';
import 'package:flutter/foundation.dart';

class CommentsController extends ChangeNotifier {
  final CommentsStore store;

  CommentsController(this.store);

  int countFor(String noteId) => store.countFor(noteId);
  List<NoteComment> commentsFor(String noteId) => store.commentsFor(noteId);
  bool get isLoading => store.isLoading;
  String? get errorMessage => store.errorMessage;

  /// 실패해도 목록은 그대로 뜬다 — 뱃지가 없는 것이 목록이 없는 것보다 낫다.
  Future<void> loadCounts() async {
    await store.loadCounts();
    notifyListeners();
  }

  /// 시트가 initState에서 부른다 — 위젯 빌드 중 notify는 Riverpod이 금지하므로
  /// (실측: "Tried to modify a provider while the widget tree was building")
  /// 완료 후에만 알린다. 로드에는 낙관 갱신이 없어 잃는 것도 없다.
  Future<void> loadFor(String noteId) async {
    await store.load(noteId);
    notifyListeners();
  }

  /// 스토어가 첫 await 전에 낙관적으로 끼워 넣는다 —
  /// 호출 직후 한 번, 완료 후 한 번 알린다 (NotesController와 같은 규칙).
  Future<void> add({required String noteId, required String body}) =>
      _tracked(store.add(noteId: noteId, body: body));

  Future<void> delete({required String id, required String noteId}) =>
      _tracked(store.delete(id: id, noteId: noteId));

  void dismissError() {
    store.dismissError();
    notifyListeners();
  }

  Future<void> _tracked(Future<void> task) async {
    notifyListeners();
    await task;
    notifyListeners();
  }
}
