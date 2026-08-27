import 'dart:async';

/// 열어 줄 때까지 기다리게 하는 문. 겹친 로드를 결정적으로 재현하기 위한 것 —
/// 시간(sleep)에 기대면 느린 기계에서 흔들린다. (Swift 테스트의 Gate actor 대응)
class Gate {
  var _isOpen = false;
  final _waiting = <Completer<void>>[];

  Future<void> wait() {
    if (_isOpen) return Future.value();
    final completer = Completer<void>();
    _waiting.add(completer);
    return completer.future;
  }

  void open() {
    _isOpen = true;
    for (final completer in _waiting) {
      completer.complete();
    }
    _waiting.clear();
  }
}

/// Swift 테스트의 `Task.yield()` 대응 — 이벤트 큐를 몇 바퀴 돌린다.
Future<void> pump([int times = 20]) async {
  for (var i = 0; i < times; i += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}
