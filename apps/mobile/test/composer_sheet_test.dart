/// 컴포저 위젯 테스트 (BRU-158). 프리뷰 컨테이너의 인메모리 리포지토리로
/// iOS `NoteComposerSheet.swift`의 계약 — 세 타깃·툴바·미리보기·canSubmit·
/// 첨부 라우팅(BRU-131)·하단 액션 줄(BRU-132) — 을 검증한다.
library;

import 'dart:typed_data';

import 'package:drop_core/drop_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/environment/drop_environment_container.dart';
import 'package:mobile/environment/providers.dart';
import 'package:mobile/notes/notes_controller.dart';
import 'package:mobile/screens/composer_sheet.dart';
import 'package:mobile/widgets/markdown_toolbar.dart';

PendingAttachment fakeAttachment({String name = '사진.png'}) =>
    PendingAttachment(
      data: Uint8List.fromList([1, 2, 3]),
      fileName: name,
      type: AttachmentType.image,
    );

/// 홈을 통째로 띄우지 않고 컴포저만 여는 최소 진입로.
/// 타깃이 목록의 노트를 가리켜야 하므로 컨트롤러를 받아 타깃을 만든다.
class ComposerHarness {
  final DropEnvironmentContainer container = DropEnvironmentContainer.preview();
  NotesController? _controller;

  NotesController get controller => _controller!;

  InMemoryAttachmentsRepository get attachments =>
      container.attachmentsRepository as InMemoryAttachmentsRepository;

  Future<void> pump(
    WidgetTester tester, {
    ComposerTarget Function(NotesController notes)? target,
    ComposerMediaPicker? pickMedia,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dropContainerProvider.overrideWithValue(container)],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              final notes = ref.watch(notesControllerProvider(null));
              _controller = notes;
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => showComposerSheet(
                      context,
                      notes,
                      target: target?.call(notes) ??
                          const ComposerTarget.newNote(),
                      pickMedia: pickMedia,
                    ),
                    child: const Text('컴포저 열기'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('컴포저 열기'));
    await tester.pumpAndSettle();
  }
}

TextField composerField(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField));

void main() {
  testWidgets('새 노트 제출은 목록에 노트를 더한다', (tester) async {
    final harness = ComposerHarness();
    await harness.pump(tester);

    expect(find.text('새 노트'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '새로 적은 노트');
    // canSubmit 재판정(setState)이 다음 프레임에 반영된다 — 탭 전에 한 번 돌린다.
    await tester.pump();
    await tester.tap(find.text('추가'));
    await tester.pumpAndSettle();

    // 시트는 닫히고, 노트는 스토어에 있다.
    expect(find.byType(ComposerSheet), findsNothing);
    expect(
      harness.controller.store.allNotes
          .where((note) => note.content == '새로 적은 노트'),
      hasLength(1),
    );
  });

  testWidgets('툴바 버튼은 커서 자리의 본문을 변환한다 (drop_core MarkdownEditor)',
      (tester) async {
    final harness = ComposerHarness();
    await harness.pump(tester);

    await tester.enterText(find.byType(TextField), '안녕');
    // enterText는 커서를 끝에 둔다 — 접힌 선택에서 굵게는 `****`를 끼우고
    // 커서를 그 가운데 둔다.
    await tester.tap(find.byTooltip('굵게'));
    await tester.pump();

    final controller = composerField(tester).controller!;
    expect(controller.text, '안녕****');
    expect(controller.selection.baseOffset, 4);
    expect(controller.selection.extentOffset, 4);

    // 제목은 줄 앞머리에 `#`을 세운다.
    await tester.tap(find.byTooltip('제목'));
    await tester.pump();
    expect(controller.text, '# 안녕****');
  });

  testWidgets('미리보기는 렌더만 하고 툴바를 걷는다 — 본문은 그대로 (BRU-66)', (tester) async {
    final harness = ComposerHarness();
    await harness.pump(tester);

    const source = '# 제목\n\n**굵게** 본문';
    await tester.enterText(find.byType(TextField), source);
    await tester.tap(find.byTooltip('미리보기 전환'));
    await tester.pumpAndSettle();

    // 편집기가 사라지고 렌더된 글이 선다. 원문 기호는 보이지 않는다.
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(MarkdownToolbar), findsNothing);
    expect(find.text('제목'), findsOneWidget);
    expect(find.textContaining('# 제목'), findsNothing);

    // 다시 편집으로 — 본문이 한 글자도 달라지지 않았다.
    await tester.tap(find.byTooltip('미리보기 전환'));
    await tester.pumpAndSettle();
    expect(find.byType(MarkdownToolbar), findsOneWidget);
    expect(composerField(tester).controller!.text, source);
  });

  testWidgets('빈 본문은 제출할 수 없고, 대기 첨부가 있으면 제출할 수 있다 (BRU-131)',
      (tester) async {
    final harness = ComposerHarness();
    await harness.pump(tester, pickMedia: () async => [fakeAttachment()]);

    // 본문도 첨부도 없다 — 추가 버튼이 죽어 있다.
    FilledButton button() =>
        tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button().onPressed, isNull);

    await tester.tap(find.byTooltip('사진 첨부'));
    await tester.pumpAndSettle();

    expect(find.text('첨부 1'), findsOneWidget);
    expect(button().onPressed, isNotNull);

    // 본문 없이 제출 — 노트가 만들어지고 첨부는 **그 노트의 id**로 올라간다.
    await tester.tap(find.text('추가'));
    await tester.pumpAndSettle();

    final uploaded = harness.attachments.attachments;
    expect(uploaded, hasLength(1));
    final created = harness.controller.store.allNotes
        .firstWhere((note) => note.content.isEmpty);
    expect(uploaded.single.noteId, created.id);
  });

  testWidgets('기존 노트 편집은 id를 유지한다 — 새 display_id가 생기지 않는다', (tester) async {
    final harness = ComposerHarness();
    await harness.pump(
      tester,
      target: (notes) => ComposerTarget.existing(
        notes.store.allNotes.firstWhere((note) => note.id == '2'),
      ),
      pickMedia: () async => [fakeAttachment()],
    );

    // 본문이 그 노트의 내용으로 미리 채워져 있고, 버튼은 '저장'이다.
    expect(find.text('노트 편집'), findsOneWidget);
    final before = harness.controller.store.allNotes;
    final beforeIds = before.map((note) => note.id).toSet();
    expect(composerField(tester).controller!.text, '장보기: 우유, 커피 원두, 사과');

    await tester.enterText(find.byType(TextField), '장보기: 수정본');
    await tester.tap(find.byTooltip('사진 첨부'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    final after = harness.controller.store.allNotes;
    // 노트 수·id 집합이 그대로다 — 어떤 노트도 새로 만들어지지 않았다.
    expect(after.length, before.length);
    expect(after.map((note) => note.id).toSet(), beforeIds);
    final edited = after.firstWhere((note) => note.id == '2');
    expect(edited.content, '장보기: 수정본');
    expect(edited.displayId, 11);
    // 첨부는 편집 중인 그 노트로 갔다 (BRU-131).
    expect(harness.attachments.attachments.single.noteId, '2');
  });

  testWidgets('답글 타깃은 부모 아래의 새 노트를 만든다 (BRU-69)', (tester) async {
    final harness = ComposerHarness();
    await harness.pump(
      tester,
      target: (notes) => ComposerTarget.reply(
        notes.store.allNotes.firstWhere((note) => note.id == '2'),
      ),
    );

    expect(find.text('답글 — #11'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '답글 본문');
    await tester.pump();
    await tester.tap(find.text('추가'));
    await tester.pumpAndSettle();

    final reply = harness.controller.store.allNotes
        .firstWhere((note) => note.content == '답글 본문');
    expect(reply.parentId, '2');
  });
}
