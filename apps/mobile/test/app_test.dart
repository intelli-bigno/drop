

import 'package:drop_core/drop_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app.dart';
import 'package:mobile/environment/drop_environment_container.dart';
import 'package:mobile/environment/providers.dart';
import 'package:mobile/screens/auth_screen.dart';
import 'package:mobile/screens/home_screen.dart';

/// 인증 경계의 테스트 대역. 실제 Supabase·Google SDK 없이 상태 전이만 흉내낸다.
class FakeAuthenticationGateway implements AuthenticationGateway {
  DropUser? storedUser;
  Object? signInError;

  FakeAuthenticationGateway({this.storedUser});

  @override
  DropUser? get currentUser => storedUser;

  @override
  Future<DropUser> signIn({required String idToken, String? accessToken}) async {
    final error = signInError;
    if (error != null) throw error;
    final user = DropUser(id: 'user-$idToken', email: 'bruce@example.com');
    storedUser = user;
    return user;
  }

  @override
  Future<void> signOut() async {
    storedUser = null;
  }
}

/// 스토리지 없는 첨부 대역 — 서명 URL을 만들 수 없고, 화면은 자리표시로 그린다.

class FakeIdentityProvider implements GoogleIdentityProvider {
  GoogleIdentity? result;

  FakeIdentityProvider({this.result});

  @override
  Future<GoogleIdentity?> signIn() async => result;

  @override
  void signOut() {}
}

DropEnvironmentContainer testContainer({
  DropUser? storedUser,
  GoogleIdentity? identity,
  List<Note> notes = const [],
}) =>
    DropEnvironmentContainer(
      configuration: null,
      isPreview: false,
      notesRepository: InMemoryNotesRepository(notes: notes),
      commentsRepository: InMemoryCommentsRepository(),
      attachmentsRepository: InMemoryAttachmentsRepository(),
      authenticationGateway: FakeAuthenticationGateway(storedUser: storedUser),
      identityProvider: FakeIdentityProvider(result: identity),
    );

Widget appWith(DropEnvironmentContainer container) => ProviderScope(
      overrides: [dropContainerProvider.overrideWithValue(container)],
      child: const DropApp(),
    );

Note note(String id, String content, {Duration age = Duration.zero}) {
  final now = DateTime.now().toUtc();
  return Note(
    id: id,
    displayId: 1,
    content: content,
    createdAt: now.subtract(age),
    updatedAt: now,
    source: NoteSource.mobile,
  );
}

void main() {
  testWidgets('저장된 세션이 없으면 로그인 화면이 뜬다', (tester) async {
    await tester.pumpWidget(appWith(testContainer()));
    await tester.pumpAndSettle();

    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.text('Google로 계속하기'), findsOneWidget);
    expect(find.text('DROP'), findsOneWidget);
  });

  testWidgets('저장된 세션이 있으면 로그인 화면 없이 홈으로 간다', (tester) async {
    await tester.pumpWidget(appWith(testContainer(
      storedUser: const DropUser(id: 'u1', email: 'bruce@example.com'),
      notes: [note('n1', '복원된 세션의 노트')],
    )));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(AuthScreen), findsNothing);
    expect(find.text('복원된 세션의 노트'), findsOneWidget);
  });

  testWidgets('Google 버튼 → 게이트웨이 로그인 → 홈 목록', (tester) async {
    await tester.pumpWidget(appWith(testContainer(
      identity: const GoogleIdentity(idToken: 'tok', accessToken: null),
      notes: [note('n1', '로그인 후 보이는 노트')],
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Google로 계속하기'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('로그인 후 보이는 노트'), findsOneWidget);
  });

  testWidgets('로그인 실패는 로그인 화면에 문구로 남는다', (tester) async {
    final container = testContainer(
      identity: const GoogleIdentity(idToken: 'tok', accessToken: null),
    );
    (container.authenticationGateway as FakeAuthenticationGateway).signInError =
        StateError('Unacceptable audience');
    await tester.pumpWidget(appWith(container));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Google로 계속하기'));
    await tester.pumpAndSettle();

    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.textContaining('Unacceptable audience'), findsOneWidget);
  });

  testWidgets('프리뷰 컨테이너는 인증 없이 표본 노트 목록을 띄운다', (tester) async {
    await tester.pumpWidget(appWith(DropEnvironmentContainer.preview()));
    await tester.pumpAndSettle();

    expect(find.byType(AuthScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    // PreviewLaunch 표본 (iOS PreviewLaunch.swift 포팅).
    expect(find.text('장보기: 우유, 커피 원두, 사과'), findsOneWidget);
    // 목록 행에는 상대 시간이 붙는다.
    expect(find.textContaining('분전'), findsWidgets);
  });
}
