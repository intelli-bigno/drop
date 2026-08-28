/// DropCore `WidgetSnapshotTests.swift` 포팅.
///
/// 위젯은 Supabase에 접속하지 않는다 — 세션도 없고 메모리 한도도 좁다.
/// 앱이 App Group에 **적어 둔 요약**만 읽어 그린다. 그 요약을 만드는 규칙이 여기 있다.
library;

import 'dart:convert';
import 'dart:io';

import 'package:drop_core/drop_core.dart';
import 'package:test/test.dart';

Note note(
  String id,
  String content, {
  required DateTime createdAt,
  DateTime? archivedAt,
  DateTime? deletedAt,
}) =>
    Note(
      id: id,
      displayId: 1,
      content: content,
      createdAt: createdAt,
      updatedAt: createdAt,
      source: NoteSource.mobile,
      archivedAt: archivedAt,
      deletedAt: deletedAt,
    );

void main() {
  final now = DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true);

  group('위젯 스냅샷 만들기', () {
    test('최신 노트를 앞에 둔다', () {
      final snapshot = WidgetSnapshot.fromNotes([
        note('오래된', '오래된',
            createdAt: now.subtract(const Duration(minutes: 10))),
        note('최신', '최신', createdAt: now),
      ], generatedAt: now);

      expect(snapshot.notes.map((n) => n.id), ['최신', '오래된']);
    });

    // 위젯 크기가 작아 더 실어도 보이지 않는다. 보관·휴지통은 애초에 "최근"이 아니다.
    test('활성 노트만, 최대 개수까지만 싣는다', () {
      final snapshot = WidgetSnapshot.fromNotes([
        note('1', '하나', createdAt: now),
        note('2', '둘', createdAt: now.subtract(const Duration(seconds: 1))),
        note('3', '셋', createdAt: now.subtract(const Duration(seconds: 2))),
        note('4', '넷', createdAt: now.subtract(const Duration(seconds: 3))),
        note('보관', '보관', createdAt: now, archivedAt: now),
        note('휴지통', '휴지통', createdAt: now, deletedAt: now),
      ], generatedAt: now);

      expect(snapshot.notes.length, WidgetSnapshot.maximumNoteCount);
      expect(snapshot.notes.map((n) => n.id), ['1', '2', '3']);
    });

    // 위젯은 한 줄씩 보여준다 — 줄바꿈이 그대로 들어오면 첫 줄만 보이고 나머지가 잘린다.
    test('여러 줄 본문을 한 줄로 접는다', () {
      final snapshot = WidgetSnapshot.fromNotes(
        [note('1', '  첫 줄\n\n 둘째   줄  ', createdAt: now)],
        generatedAt: now,
      );

      expect(snapshot.notes.first.excerpt, '첫 줄 둘째 줄');
    });

    test('긴 본문은 말줄임표까지 포함해 상한 길이로 자른다', () {
      final long = '가' * 200;

      final snapshot =
          WidgetSnapshot.fromNotes([note('1', long, createdAt: now)],
              generatedAt: now);
      final excerpt = snapshot.notes.first.excerpt;

      expect(excerpt.runes.length, WidgetSnapshot.excerptLimit);
      expect(excerpt.endsWith('…'), isTrue);
    });

    test('상한과 같은 길이는 자르지 않는다', () {
      final exact = '나' * WidgetSnapshot.excerptLimit;

      final snapshot =
          WidgetSnapshot.fromNotes([note('1', exact, createdAt: now)],
              generatedAt: now);

      expect(snapshot.notes.first.excerpt, exact);
    });

    // 사진만 붙인 노트는 본문이 빈다. 빈 줄로 두면 위젯에 아무것도 없는 칸이 생긴다.
    test('본문이 빈 노트는 대체 문구로 보여준다', () {
      final snapshot = WidgetSnapshot.fromNotes(
        [note('1', '   \n ', createdAt: now)],
        generatedAt: now,
      );

      expect(
        snapshot.notes.first.excerpt,
        WidgetSnapshot.emptyContentPlaceholder,
      );
    });

    test('보여줄 노트가 없으면 빈 스냅샷이다', () {
      final snapshot = WidgetSnapshot.fromNotes(
        [note('휴지통', '휴지통', createdAt: now, deletedAt: now)],
        generatedAt: now,
      );

      expect(snapshot.isEmpty, isTrue);
      expect(WidgetSnapshot.empty.isEmpty, isTrue);
    });
  });

  group('위젯 스냅샷 저장소', () {
    late Directory directory;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('widget-snapshot-test');
    });

    tearDown(() {
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });

    WidgetSnapshotStore makeStore() => WidgetSnapshotStore(directory);

    test('쓴 것을 그대로 읽는다', () {
      final store = makeStore();
      final snapshot = WidgetSnapshot(
        notes: [WidgetNote(id: '1', excerpt: '메모', createdAt: now)],
        generatedAt: now.add(const Duration(seconds: 1)),
      );

      store.write(snapshot);

      expect(store.read(), snapshot);
    });

    // 아직 앱을 한 번도 켜지 않았으면 파일이 없다. 위젯은 그래도 그려져야 한다.
    test('파일이 없으면 빈 스냅샷을 돌려준다', () {
      expect(makeStore().read(), WidgetSnapshot.empty);
    });

    // 쓰다가 앱이 죽으면 반쯤 쓴 파일이 남는다 — 위젯이 거기서 멈추면 안 된다.
    test('깨진 파일도 빈 스냅샷으로 읽는다', () {
      final store = makeStore();
      store.write(WidgetSnapshot(notes: const [], generatedAt: now));
      store.file.writeAsStringSync('망가진 내용');

      expect(store.read(), WidgetSnapshot.empty);
    });

    test('나중에 쓴 스냅샷이 앞의 것을 덮는다', () {
      final store = makeStore();
      store.write(WidgetSnapshot(
        notes: [
          WidgetNote(
              id: '옛것',
              excerpt: '옛것',
              createdAt: DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true))
        ],
        generatedAt: DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
      ));

      store.write(WidgetSnapshot(
        notes: [
          WidgetNote(
              id: '새것',
              excerpt: '새것',
              createdAt: DateTime.fromMillisecondsSinceEpoch(2000, isUtc: true))
        ],
        generatedAt: DateTime.fromMillisecondsSinceEpoch(2000, isUtc: true),
      ));

      expect(store.read().notes.map((n) => n.id), ['새것']);
    });

    // 앱·공유확장이 이미 쓰는 그룹을 그대로 쓴다. 새 그룹은 포털 수작업을 부른다.
    test('공유 수신함과 같은 App Group을 쓴다', () {
      expect(WidgetSnapshotStore.appGroupId, SharedInbox.appGroupId);
    });

    // 읽는 쪽은 위젯(Swift ISO8601 디코더)이다 — snake_case 키와 ISO8601
    // 시각 문자열이 계약이다.
    test('Swift 위젯이 읽는 JSON 형태로 적는다', () {
      final store = makeStore();
      store.write(WidgetSnapshot(
        notes: [WidgetNote(id: '1', excerpt: '메모', createdAt: now)],
        generatedAt: now,
      ));

      final decoded =
          jsonDecode(store.file.readAsStringSync()) as Map<String, Object?>;
      final noteJson =
          (decoded['notes'] as List).first as Map<String, Object?>;

      expect(noteJson.keys, containsAll(['id', 'excerpt', 'created_at']));
      expect(noteJson['created_at'], '2023-11-14T22:13:20.000Z');
      expect(decoded['generated_at'], '2023-11-14T22:13:20.000Z');
    });
  });
}
