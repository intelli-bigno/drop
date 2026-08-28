/// 딥링크 → 화면 이동 배선 (BRU-160). 해석 규칙 자체는 drop_core
/// `drop_link_test.dart`가 덮는다 — 여기서는 배선만 본다.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app.dart';
import 'package:mobile/environment/drop_environment_container.dart';
import 'package:mobile/environment/providers.dart';
import 'package:mobile/screens/home_screen.dart';
import 'package:mobile/screens/note_detail_screen.dart';

void main() {
  late StreamController<Uri> links;

  setUp(() => links = StreamController<Uri>.broadcast());
  tearDown(() => links.close());

  Widget previewApp() => ProviderScope(
        overrides: [
          dropContainerProvider
              .overrideWithValue(DropEnvironmentContainer.preview()),
        ],
        child: DropApp(linkStream: links.stream),
      );

  testWidgets('drop://note/<id> 링크는 그 노트의 뷰어를 연다', (tester) async {
    await tester.pumpWidget(previewApp());
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);

    // 프리뷰 표본의 첫 노트 id (PreviewLaunch 포팅 표본).
    final container = DropEnvironmentContainer.preview();
    final notes = await container.notesRepository.loadNotes();
    links.add(Uri.parse('drop://note/${notes.first.id}'));
    await tester.pumpAndSettle();

    expect(find.byType(NoteDetailScreen), findsOneWidget);
  });

  testWidgets('drop://compose 링크는 새 노트 컴포저를 연다', (tester) async {
    await tester.pumpWidget(previewApp());
    await tester.pumpAndSettle();

    links.add(Uri.parse('drop://compose?text=%EB%A9%94%EB%AA%A8'));
    await tester.pumpAndSettle();

    // 시트가 본문이 미리 채워진 채로 열린다.
    expect(find.text('새 노트'), findsWidgets);
    expect(find.text('메모'), findsOneWidget);
  });

  testWidgets('모르는 링크는 화면을 옮기지 않는다', (tester) async {
    await tester.pumpWidget(previewApp());
    await tester.pumpAndSettle();

    links.add(Uri.parse('com.googleusercontent.apps.123:/oauth2redirect'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(NoteDetailScreen), findsNothing);
  });
}
