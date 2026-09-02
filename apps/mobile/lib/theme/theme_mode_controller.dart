/// 라이트·다크·시스템 — 사용자가 고른 테마 (BRU-207).
///
/// 기본은 시스템 추종이다. 고른 값은 기기에 남긴다 — 앱을 다시 열었을 때 테마가
/// 되돌아가 있으면 "설정이 안 먹었다"가 된다. 저장소(shared_preferences)가 없는
/// 환경(테스트·일부 웹)에서는 조용히 메모리로만 돈다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

class ThemeModeController extends Notifier<ThemeMode> {
  static const _key = 'drop.themeMode';

  @override
  ThemeMode build() {
    _restore();
    return ThemeMode.system;
  }

  Future<void> _restore() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getString(_key);
      final mode = ThemeMode.values.where((m) => m.name == saved);
      if (mode.isNotEmpty) state = mode.first;
    } catch (_) {
      // 저장소가 없으면 시스템 추종으로 남는다.
    }
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    try {
      await (await SharedPreferences.getInstance()).setString(_key, mode.name);
    } catch (_) {}
  }

  static String label(ThemeMode mode) => switch (mode) {
    ThemeMode.system => '시스템 설정 따르기',
    ThemeMode.light => '라이트',
    ThemeMode.dark => '다크',
  };
}
