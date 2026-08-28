/// DropCore `SharedInboxTests.swift`의 「공유 수신함」 스위트 포팅.
///
/// Share Extension은 앱이 실행 중이 아닐 수도 있고, 메모리 한도(약 120MB)도 좁다.
/// 그래서 확장은 App Group 컨테이너에 **적어 두기만** 하고, 앱이 켜질 때 비운다.
library;

import 'dart:convert';
import 'dart:io';

import 'package:drop_core/drop_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('shared-inbox-test');
  });

  tearDown(() {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  SharedInbox makeInbox() => SharedInbox(directory);

  test('적어 둔 항목을 순서대로 꺼낸다', () {
    final inbox = makeInbox();

    inbox.enqueue(SharedItem(
      text: '첫 번째',
      createdAt: DateTime.utc(2023, 11, 14, 22, 13, 20),
    ));
    inbox.enqueue(SharedItem(
      text: '두 번째',
      createdAt: DateTime.utc(2023, 11, 14, 22, 13, 21),
    ));

    expect(inbox.drain().map((item) => item.text), ['첫 번째', '두 번째']);
  });

  // 두 번 처리하면 노트가 두 번 만들어진다. 꺼낸 항목은 반드시 지워져야 한다.
  test('한 번 꺼내면 비워진다', () {
    final inbox = makeInbox();
    inbox.enqueue(SharedItem(text: '한 번만'));

    inbox.drain();

    expect(inbox.drain(), isEmpty);
  });

  test('빈 수신함을 꺼내도 오류가 아니다', () {
    expect(makeInbox().drain(), isEmpty);
  });

  // 확장이 죽으면서 반쯤 쓴 파일이 남을 수 있다. 그것 하나가 전체 처리를 막으면 안 된다.
  test('깨진 항목은 건너뛰고 나머지를 처리한다', () {
    final inbox = makeInbox();
    inbox.enqueue(SharedItem(text: '정상'));
    File('${directory.path}/item-broken.json').writeAsStringSync('망가진 내용');

    final items = inbox.drain();

    expect(items.map((item) => item.text), ['정상']);
    // 깨진 파일도 함께 치운다 — 남겨 두면 매번 실패를 반복한다.
    expect(inbox.drain(), isEmpty);
  });

  test('첨부 파일 이름을 함께 실어 나른다', () {
    final inbox = makeInbox();
    inbox.enqueue(SharedItem(text: '사진', fileNames: ['a.jpg', 'b.jpg']));

    expect(inbox.drain().first.fileNames, ['a.jpg', 'b.jpg']);
  });

  // Share Extension(Swift)이 쓰는 JSON을 그대로 읽어야 한다 —
  // snake_case 키 + ISO8601 분수초가 이쪽 계약이다.
  test('Swift 확장이 적은 JSON을 읽는다', () {
    final inbox = makeInbox();
    directory.createSync(recursive: true);
    File('${directory.path}/item-1700000000.123456-abc.json').writeAsStringSync(
      jsonEncode({
        'text': '확장에서 온 글',
        'file_names': ['shared.jpg'],
        'created_at': '2023-11-14T22:13:20.123Z',
      }),
    );

    final items = inbox.drain();

    expect(items.single.text, '확장에서 온 글');
    expect(items.single.fileNames, ['shared.jpg']);
    expect(items.single.createdAt, DateTime.utc(2023, 11, 14, 22, 13, 20, 123));
  });
}
