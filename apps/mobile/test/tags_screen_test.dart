import 'package:drop_core/drop_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/environment/drop_environment_container.dart';
import 'package:mobile/environment/providers.dart';
import 'package:mobile/screens/tags_screen.dart';
import 'package:mobile/theme/drop_theme.dart';

/// 인증 경계의 최소 대역 — 이 화면은 인증을 건드리지 않는다.
class _NoAuthGateway implements AuthenticationGateway {
  const _NoAuthGateway();

  @override
  DropUser? get currentUser => null;

  @override
  Future<DropUser> signIn({required String idToken, String? accessToken}) =>
      throw UnimplementedError();

  @override
  Future<void> signOut() async {}
}

class _NoIdentityProvider implements GoogleIdentityProvider {
  const _NoIdentityProvider();

  @override
  Future<GoogleIdentity?> signIn() async => null;

  @override
  void signOut() {}
}

Tag tag(String name) =>
    Tag(id: name, name: name, createdAt: DateTime.utc(2026, 1, 1));

Note note(
  String id, {
  List<Tag> tags = const [],
  DateTime? archivedAt,
  DateTime? deletedAt,
}) {
  final now = DateTime.utc(2026, 1, 2);
  return Note(
    id: id,
    displayId: 1,
    content: '노트 $id',
    tags: tags,
    createdAt: now,
    updatedAt: now,
    archivedAt: archivedAt,
    deletedAt: deletedAt,
    source: NoteSource.mobile,
  );
}

Widget screenWith(List<Note> notes) => ProviderScope(
      overrides: [
        dropContainerProvider.overrideWithValue(DropEnvironmentContainer(
          configuration: null,
          isPreview: true,
          notesRepository: InMemoryNotesRepository(notes: notes),
          commentsRepository: InMemoryCommentsRepository(),
          attachmentsRepository: InMemoryAttachmentsRepository(),
          authenticationGateway: const _NoAuthGateway(),
          identityProvider: const _NoIdentityProvider(),
        )),
      ],
      child: MaterialApp(
        theme: DropTheme.light,
        home: const TagsScreen(userId: 'preview'),
      ),
    );

void main() {
  group('tagCounts', () {
    test('활성 노트만 세고 많이 쓰인 순으로 정렬한다', () {
      final dev = tag('개발');
      final home = tag('집');
      final store = NotesStore(repository: InMemoryNotesRepository())
        ..allNotes = [
          note('1', tags: [dev]),
          note('2', tags: [dev, home]),
          note('3', tags: [home], deletedAt: DateTime.utc(2026, 1, 3)),
        ];

      final counts = tagCounts(store);

      expect(counts.map((entry) => entry.tag.name), ['개발', '집']);
      expect(counts.map((entry) => entry.count), [2, 1]);
    });

    test('휴지통·보관에만 남은 태그는 0으로 나온다', () {
      final store = NotesStore(repository: InMemoryNotesRepository())
        ..allNotes = [
          note('1',
              tags: [tag('묵힘')], archivedAt: DateTime.utc(2026, 1, 3)),
        ];

      expect(tagCounts(store).single.count, 0);
    });
  });

  testWidgets('태그가 없으면 빈 상태를 보여 준다', (tester) async {
    await tester.pumpWidget(screenWith([note('1')]));
    await tester.pumpAndSettle();

    expect(find.text('태그가 없습니다'), findsOneWidget);
  });

  testWidgets('태그 행을 탭하면 필터가 걸리고, 필터 해제로 풀린다', (tester) async {
    await tester.pumpWidget(screenWith([
      note('1', tags: [tag('개발')]),
      note('2', tags: [tag('개발')]),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('#개발'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('필터 해제'), findsNothing);

    await tester.tap(find.text('#개발'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.text('필터 해제'), findsOneWidget);

    await tester.tap(find.text('필터 해제'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check), findsNothing);
    expect(find.text('필터 해제'), findsNothing);
  });
}
