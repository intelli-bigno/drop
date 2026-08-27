/// drop_core `CommentsStore`를 화면이 구독할 수 있게 감싼다.
/// 홈 목록은 뱃지 숫자만 쓴다 — 댓글 목록 자체는 BRU-157(뷰어)의 몫이다.
library;

import 'package:drop_core/drop_core.dart';
import 'package:flutter/foundation.dart';

class CommentsController extends ChangeNotifier {
  final CommentsStore store;

  CommentsController(this.store);

  int countFor(String noteId) => store.countFor(noteId);

  /// 실패해도 목록은 그대로 뜬다 — 뱃지가 없는 것이 목록이 없는 것보다 낫다.
  Future<void> loadCounts() async {
    await store.loadCounts();
    notifyListeners();
  }
}
