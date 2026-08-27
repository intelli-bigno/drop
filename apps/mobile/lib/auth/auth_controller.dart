/// drop_core `AuthStore`(순수 상태 전이)를 화면이 구독할 수 있게 감싼다.
/// iOS에서는 `@Observable`이 하던 몫 — 상태 전이 규칙 자체는 전부 drop_core에 있다.
library;

import 'package:drop_core/drop_core.dart';
import 'package:flutter/foundation.dart';

class AuthController extends ChangeNotifier {
  final AuthStore store;

  AuthController(this.store);

  AuthState get state => store.state;
  DropUser? get user => store.user;

  /// 앱 시작 시 저장된 세션을 확인한다 (iOS `.task { await auth.restore() }` 대응).
  Future<void> restore() async {
    await store.restore();
    notifyListeners();
  }

  Future<void> signInWithGoogle() async {
    final task = store.signInWithGoogle();
    // AuthStore는 첫 await 전에 동기적으로 working이 되므로,
    // 여기서 한 번 알리면 버튼 스피너가 즉시 뜬다.
    notifyListeners();
    await task;
    notifyListeners();
  }

  Future<void> signOut() async {
    await store.signOut();
    notifyListeners();
  }
}
