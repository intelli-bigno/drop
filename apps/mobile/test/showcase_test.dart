/// 쇼케이스가 실제로 뜨는지 (BRU-193).
///
/// 쇼케이스는 사람이 눈으로 보라고 만든 것이라 **아무도 자동으로 열어 보지 않는다** —
/// 위젯 하나의 생성자가 바뀌면 조용히 죽고, 다음에 열어 본 사람이 발견한다.
/// 그래서 페이지마다 한 번씩 그려 본다.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/showcase/parts.dart';
import 'package:mobile/showcase/showcase_app.dart';

void main() {
  group('쇼케이스 셸', () {
    testWidgets('모든 페이지가 예외 없이 그려진다', (tester) async {
      // 폰보다 넓게 잡아 좌측 내비가 펼쳐진 배치로 검사한다.
      tester.view.physicalSize = const Size(1400, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const ShowcaseApp());
      await tester.pumpAndSettle();

      for (final page in showcasePages) {
        await tester.tap(find.byKey(ValueKey('showcase-nav-${page.id}')));
        // pumpAndSettle을 쓰면 States의 로딩 스피너(영원히 도는 애니메이션)에서
        // 영영 안 끝난다 — 정해진 프레임만 흘린다.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        // PageHead가 섰다는 것은 그 섹션이 끝까지 그려졌다는 뜻이다 —
        // 표본 하나라도 생성자에서 터지면 여기까지 오지 못한다.
        expect(
          find.byType(PageHead),
          findsOneWidget,
          reason: '${page.id} 페이지가 그려지지 않았다',
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('테마를 다크로 바꾸면 다크 테마가 적용된다', (tester) async {
      tester.view.physicalSize = const Size(1400, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const ShowcaseApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text(ShowcaseTheme.dark.label));
      await tester.pumpAndSettle();

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.dark);
    });
  });

  test('표본이 가리키는 파일 경로가 실재한다', () {
    // Specimen의 `file`은 "이 물건이 실제로 사는 곳"이다. 파일이 옮겨졌는데
    // 경로가 남으면 쇼케이스를 보고 코드로 가려던 사람이 헛걸음한다.
    final referenced = <String>{};
    final pattern = RegExp(r"file:\s*'([^']+)'");

    for (final file in Directory('lib/showcase')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))) {
      for (final match in pattern.allMatches(file.readAsStringSync())) {
        referenced.add(match.group(1)!);
      }
    }

    expect(referenced, isNotEmpty, reason: '표본이 하나도 경로를 달고 있지 않다');
    for (final path in referenced) {
      expect(File(path).existsSync(), isTrue, reason: '없는 경로를 가리킨다: $path');
    }
  });
}
