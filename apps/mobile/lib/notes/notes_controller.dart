/// drop_core `NotesStore`(순수 상태 전이)를 화면이 구독할 수 있게 감싼다.
/// 진짜 피드는 BRU-156 — 여기는 목록을 읽는 최소한만 있다.
library;

import 'package:drop_core/drop_core.dart';
import 'package:flutter/foundation.dart';

class NotesController extends ChangeNotifier {
  final NotesStore store;

  NotesController(this.store);

  Future<void> load() async {
    final task = store.load();
    // NotesStore는 첫 await 전에 동기적으로 isLoading이 되므로 즉시 한 번 알린다.
    notifyListeners();
    await task;
    notifyListeners();
  }
}
