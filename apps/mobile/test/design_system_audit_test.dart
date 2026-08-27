/// 화면 코드가 디자인 규칙을 지키는지 **소스를 읽어서** 검증한다 —
/// iOS `DesignSystemAuditTests.swift`(BRU-75)의 Dart판.
///
/// 규칙: 화면·테마 소스에 리터럴 색을 적지 않는다. 색의 정본은
/// `design-system/drop/tokens.json`이고 `lib/theme/drop_tokens.g.dart`(생성물)만
/// 값을 품는다. 눈으로만 지키면 다음 화면이 추가되는 순간 조용히 무너진다.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 색 리터럴·머티리얼 기본 팔레트를 부르는 표현들.
/// `DropColors.`·`DropTokenColors.`가 걸리지 않도록 식별자 경계를 본다.
final banned = [
  RegExp(r'(?<![A-Za-z0-9_])Colors\.'), // 머티리얼 기본 팔레트 — 웜 페이퍼가 아니다
  RegExp(r'(?<![A-Za-z0-9_])Color\(0x'),
  RegExp(r'(?<![A-Za-z0-9_])Color\.fromARGB'),
  RegExp(r'(?<![A-Za-z0-9_])Color\.fromRGBO'),
];

/// 예외 파일 (경로 끝부분으로 비교).
/// iOS의 paletteDefinitionFiles 대응 — 생성물은 값의 운반자라 당연히 리터럴이다.
/// (drop_theme.dart는 뜻만 붙이는 계층이라 예외가 아니다 — 값이 새면 잡혀야 한다.)
const exemptSuffixes = [
  'lib/theme/drop_tokens.g.dart',
  // 미디어 전면 뷰어는 테마와 무관한 검정 캔버스다 — iOS MediaViewer와 같은
  // chrome 예외 (iOS DesignSystemAuditTests의 chrome 목록 대응).
  'lib/screens/media_viewer_screen.dart',
];

void main() {
  test('화면·테마 소스에 리터럴 색이 남아 있지 않다', () {
    final sources = [
      ...Directory('lib/screens')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart')),
      File('lib/theme/drop_theme.dart'),
    ];

    final offenders = <String>[];
    for (final file in sources) {
      if (exemptSuffixes.any(file.path.endsWith)) continue;
      final lines = file.readAsLinesSync();
      for (var index = 0; index < lines.length; index += 1) {
        // 주석은 검사 대상이 아니다 — 규칙을 설명하는 문장까지 잡으면 주석을 못 쓴다.
        final code = lines[index].split('//').first;
        for (final needle in banned) {
          if (needle.hasMatch(code)) {
            offenders.add('${file.path}:${index + 1} — ${needle.pattern}');
          }
        }
      }
    }

    expect(offenders, isEmpty,
        reason: '리터럴 색 잔존 (토큰을 써라):\n${offenders.join('\n')}');
  });
}
