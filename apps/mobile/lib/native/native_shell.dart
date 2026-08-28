/// 네이티브 셸과의 통로 (BRU-160). iOS 쪽 짝은 `ios/Runner/NativeShellChannel.swift`.
///
/// 채널이 하는 일은 둘뿐이다 — App Group 컨테이너 경로 조회와 위젯 리로드.
/// 공유 수신함 파싱·위젯 스냅샷 빌드는 전부 drop_core(순수 Dart)가 한다.
library;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NativeShell {
  static const MethodChannel _channel = MethodChannel('drop/native_shell');

  const NativeShell();

  /// App Group 컨테이너 경로. 설정돼 있지 않으면(안드로이드·테스트·엔타이틀먼트
  /// 누락) null — 이 경우 공유·위젯 기능만 동작하지 않고 앱의 나머지는 그대로다.
  Future<String?> appGroupContainerPath() async {
    try {
      return await _channel.invokeMethod<String>('appGroupContainerPath');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// 위젯 타임라인 리로드 (iOS `WidgetCenter.reloadAllTimelines` 대응).
  /// 실패해도 앱은 그대로 간다 — 위젯이 한 박자 늦게 갱신될 뿐이다.
  Future<void> reloadWidgets() async {
    try {
      await _channel.invokeMethod<void>('reloadWidgets');
    } on MissingPluginException {
      // 무시
    } on PlatformException {
      // 무시
    }
  }
}

/// 테스트가 가짜 경로를 밀어 넣는 자리.
final nativeShellProvider = Provider<NativeShell>((ref) => const NativeShell());
