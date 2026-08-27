import 'dart:convert';

import 'package:drop_core/drop_core.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// DropCore `SupabaseNotesRepositoryTests.swift` 포팅.
/// 실제 네트워크 없이 REST 경로를 태워 본다 (Swift의 URLProtocol 스텁 대응 =
/// `MockClient`). **우리 디코더가 실제 경로에 물려 있는지**를 확인한다 —
/// snake_case와 분수초 timestamptz에서 조용히 깨지면 안 된다.
void main() {
  http.Response json(int status, String body) => http.Response.bytes(
        utf8.encode(body),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  SupabaseNotesRepository makeRepository(
    http.Response Function(http.Request) responder,
  ) =>
      SupabaseNotesRepository(
        client: SupabaseRestClient(
          httpClient: MockClient((request) async => responder(request)),
          baseUrl: Uri.parse('https://stub.supabase.co'),
          anonKey: 'anon',
          session: FakeSession(userId: 'user-1'),
        ),
      );

  group('Supabase 노트 리포지토리', () {
    test('목록 응답을 모델로 읽는다', () async {
      final repository = makeRepository((request) {
        final path = request.url.path;
        if (path.endsWith('/notes')) {
          return json(200, '''
          [{"id":"n1","display_id":3,"content":"본문","created_at":"2026-08-11T09:30:00.123456+00:00",
            "updated_at":"2026-08-11T09:30:00+00:00","source":"mobile","is_pinned":false}]
          ''');
        }
        if (path.endsWith('/attachments')) {
          return json(200, '''
          [{"id":"a1","note_id":"n1","type":"image","storage_path":"p/a1",
            "created_at":"2026-08-11T09:30:00+00:00"}]
          ''');
        }
        return json(200, '''
        [{"note_id":"n1","tags":{"id":"t1","name":"일","created_at":"2026-08-01T00:00:00+00:00"}}]
        ''');
      });

      final notes = await repository.loadNotes();

      expect(notes.length, 1);
      expect(notes[0].displayId, 3);
      expect(notes[0].attachments.map((a) => a.id), ['a1']);
      expect(notes[0].tags.map((t) => t.name), ['일']);
    });

    /// 노트가 없으면 첨부·태그 쿼리를 아예 보내지 않아야 한다.
    /// 빈 `in` 필터는 PostgREST에서 오류이거나 전체 조회가 되어버린다.
    test('노트가 없으면 뒤따르는 쿼리를 보내지 않는다', () async {
      final paths = <String>[];
      final repository = makeRepository((request) {
        paths.add(request.url.path);
        return json(200, '[]');
      });

      final notes = await repository.loadNotes();

      expect(notes, isEmpty);
      expect(paths.where((p) => p.endsWith('/attachments')), isEmpty);
    });

    test('서버 거절은 rejected 오류로 좁힌다', () async {
      final repository = makeRepository(
        (_) => json(403, '{"message":"권한이 없습니다","code":"42501"}'),
      );

      await expectLater(
        repository.loadNotes(),
        throwsA(const NotesRepositoryError.rejected('권한이 없습니다')),
      );
    });

    /// Rule B (BRU-115): 휴지통 진입은 archived_at을 함께 비우고,
    /// 복원은 무조건 받은편지함으로 되돌린다.
    test('휴지통 진출입은 archived_at을 함께 비운다 — Rule B', () async {
      final patches = <Map<String, Object?>>[];
      final repository = makeRepository((request) {
        if (request.method == 'PATCH') {
          patches.add((jsonDecode(request.body) as Map).cast());
          return json(204, '');
        }
        return json(200, '[]');
      });

      await repository.moveToTrash('n1');
      await repository.restoreFromTrash('n1');

      expect(patches[0]['is_deleted'], true);
      expect(patches[0]['deleted_at'], isNotNull);
      expect(patches[0].containsKey('archived_at'), isTrue);
      expect(patches[0]['archived_at'], isNull);

      expect(patches[1]['is_deleted'], false);
      expect(patches[1]['deleted_at'], isNull);
      expect(patches[1]['archived_at'], isNull);
    });

    /// user_id를 빠뜨리면 RLS가 거부한다 — 로그인 없이 만들 수 없다.
    test('로그인 없이 노트를 만들면 notAuthenticated로 실패한다', () async {
      final repository = SupabaseNotesRepository(
        client: SupabaseRestClient(
          httpClient: MockClient((_) async => json(200, '[]')),
          baseUrl: Uri.parse('https://stub.supabase.co'),
          anonKey: 'anon',
          session: FakeSession(userId: null),
        ),
      );

      await expectLater(
        repository.createNote(content: '본문'),
        throwsA(const NotesRepositoryError.notAuthenticated()),
      );
    });
  });
}

class FakeSession implements SupabaseSessionProvider {
  final String? userId;

  FakeSession({required this.userId});

  @override
  String? get accessToken => null;

  @override
  String? get currentUserId => userId;
}
