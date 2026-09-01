/// 화면 코드가 디자인 규칙을 지키는지 **소스를 읽어서** 검증한다 —
/// iOS `DesignSystemAuditTests.swift`(BRU-75)의 Dart판.
///
/// 규칙 둘:
///   1. 리터럴 색을 적지 않는다. 색의 정본은 `design-system/drop/tokens.json`이고
///      `lib/theme/drop_tokens.g.dart`(생성물)만 값을 품는다.
///   2. 글자 크기를 숫자로 적지 않는다. 크기의 역할 이름은 `DropText`에 있다 (BRU-193).
///
/// 눈으로만 지키면 다음 화면이 추가되는 순간 조용히 무너진다.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 색 리터럴·머티리얼 기본 팔레트를 부르는 표현들.
/// `DropColors.`·`DropTokenColors.`가 걸리지 않도록 식별자 경계를 본다.
final bannedColors = [
  RegExp(r'(?<![A-Za-z0-9_])Colors\.'), // 머티리얼 기본 팔레트 — 웜 페이퍼가 아니다
  RegExp(r'(?<![A-Za-z0-9_])Color\(0x'),
  RegExp(r'(?<![A-Za-z0-9_])Color\.fromARGB'),
  RegExp(r'(?<![A-Za-z0-9_])Color\.fromRGBO'),
];

/// `fontSize: 11` 같은 숫자. `fontSize: DropTokenTextSize.xs`는 걸리지 않는다.
final bannedSizes = [RegExp(r'fontSize:\s*[0-9]')];

/// 감사 대상. 화면·위젯·테마가 다 들어간다.
///
/// `lib/widgets`가 오래 빠져 있었다 (BRU-193에서 넣음) — 그동안 위젯에
/// 리터럴 색을 적어도 그린이었다. 검사받지 않는 디렉토리는 반드시 새는 자리가 된다.
const auditedDirectories = ['lib/screens', 'lib/widgets', 'lib/showcase'];
const auditedFiles = ['lib/theme/drop_theme.dart'];

/// 예외 파일 (경로 끝부분으로 비교).
/// iOS의 paletteDefinitionFiles 대응 — 생성물은 값의 운반자라 당연히 리터럴이다.
/// (drop_theme.dart는 뜻만 붙이는 계층이라 예외가 아니다 — 값이 새면 잡혀야 한다.)
const exemptSuffixes = [
  'lib/theme/drop_tokens.g.dart',
  // 미디어 전면 뷰어는 테마와 무관한 검정 캔버스다 — iOS MediaViewer와 같은
  // chrome 예외 (iOS DesignSystemAuditTests의 chrome 목록 대응).
  'lib/screens/media_viewer_screen.dart',
];

/// 감사 대상 파일을 모은다. 없는 디렉토리는 건너뛴다.
List<File> auditedSources() => [
      for (final directory in auditedDirectories)
        if (Directory(directory).existsSync())
          ...Directory(directory)
              .listSync(recursive: true)
              .whereType<File>()
              .where((file) => file.path.endsWith('.dart')),
      for (final path in auditedFiles)
        if (File(path).existsSync()) File(path),
    ];

/// 규칙 하나를 대상 전체에 대고 걸린 자리를 돌려준다.
List<String> offendersFor(List<RegExp> banned) {
  final offenders = <String>[];
  for (final file in auditedSources()) {
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
  return offenders;
}

void main() {
  test('감사 대상이 실제로 모인다', () {
    // 경로 오타로 목록이 비면 아래 두 검사가 "위반 없음"으로 그린이 된다 —
    // 규칙이 꺼진 것을 통과로 읽는 사고를 막는다.
    expect(auditedSources(), isNotEmpty);
    for (final directory in auditedDirectories) {
      expect(Directory(directory).existsSync(), isTrue,
          reason: '감사 대상 디렉토리가 없다: $directory');
    }
  });

  test('화면·위젯·테마 소스에 리터럴 색이 남아 있지 않다', () {
    expect(offendersFor(bannedColors), isEmpty,
        reason: '리터럴 색 잔존 (토큰을 써라):\n${offendersFor(bannedColors).join('\n')}');
  });

  test('글자 크기를 숫자로 적지 않는다 — DropText의 역할 이름을 쓴다', () {
    expect(offendersFor(bannedSizes), isEmpty,
        reason: '숫자 글자 크기 잔존 (DropText를 써라):\n'
            '${offendersFor(bannedSizes).join('\n')}');
  });
}
