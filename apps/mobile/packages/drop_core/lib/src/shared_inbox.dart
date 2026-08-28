/// 확장과 앱이 App Group 컨테이너를 통해 주고받는 수신함.
/// DropCore `SharedInbox.swift` 대응.
///
/// 확장에서 곧바로 Supabase에 쓰지 않는 이유는 둘이다:
/// 확장은 메모리 한도(약 120MB)가 좁고, 세션이 없을 수도 있다.
/// 그래서 **적어 두기만** 하고 앱이 켜질 때 비운다.
///
/// 쓰는 쪽(Share Extension)은 Swift(`ios/DropShare`)다 — 파일 이름·JSON 키가
/// 이 파일과 계약이다. 여기(Dart)는 앱이 비우는 쪽과, 테스트용 enqueue를 든다.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'drop_json.dart';

/// Share Extension이 앱에 넘기는 한 건.
class SharedItem {
  final String text;

  /// App Group 컨테이너에 함께 저장한 파일 이름들.
  final List<String> fileNames;
  final DateTime createdAt;

  SharedItem({
    required this.text,
    this.fileNames = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toUtc();

  factory SharedItem.fromJson(Map<String, Object?> json) => SharedItem(
        text: json['text'] as String,
        fileNames: [
          for (final name in json['file_names'] as List<Object?>? ?? [])
            name as String,
        ],
        createdAt: parsePostgresTimestamp(json['created_at'] as String),
      );

  Map<String, Object?> toJson() => {
        'text': text,
        'file_names': fileNames,
        'created_at': formatPostgresTimestamp(createdAt),
      };
}

class SharedInbox {
  /// 예전 Flutter 앱 시절부터 쓰던 그룹이다. 새로 만들면 App Group 연결에
  /// 포털 수작업이 필요해진다(공개 API에 App Group 엔드포인트가 없다).
  static const appGroupId = 'group.com.intellieffect.drop.shared';

  /// App Group 컨테이너 안의 `inbox/` 디렉토리.
  final Directory containerDirectory;

  const SharedInbox(this.containerDirectory);

  static final _random = Random();

  /// 테스트와 확장 스펙 검증용. 실기기에서 적는 쪽은 Share Extension(Swift)이다.
  void enqueue(SharedItem item) {
    containerDirectory.createSync(recursive: true);
    // Swift와 같은 이름 규칙: 초 단위 epoch(소수점 포함)이 앞에 와서
    // 이름 정렬이 곧 시간 순서가 된다.
    final epoch =
        (item.createdAt.millisecondsSinceEpoch / 1000).toStringAsFixed(6);
    final suffix = List.generate(
      32,
      (_) => _random.nextInt(16).toRadixString(16),
    ).join();
    File('${containerDirectory.path}/item-$epoch-$suffix.json')
        .writeAsStringSync(jsonEncode(item.toJson()));
  }

  /// 파일을 저장할 위치(확장이 이미지·동영상을 복사해 두는 곳).
  String filePath(String name) => '${containerDirectory.path}/files/$name';

  void prepareFilesDirectory() =>
      Directory('${containerDirectory.path}/files').createSync(recursive: true);

  /// 쌓인 항목을 모두 꺼내고 비운다.
  ///
  /// 꺼낸 항목은 반드시 지운다 — 남기면 앱을 켤 때마다 같은 노트가 다시 만들어진다.
  /// 깨진 파일 하나가 나머지를 막지 않도록, 읽기에 실패한 것도 함께 치운다.
  List<SharedItem> drain() {
    if (!containerDirectory.existsSync()) return [];

    final files = containerDirectory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => a.uri.pathSegments.last.compareTo(b.uri.pathSegments.last));

    final items = <SharedItem>[];
    for (final file in files) {
      try {
        final decoded = jsonDecode(file.readAsStringSync());
        items.add(SharedItem.fromJson(decoded as Map<String, Object?>));
      } catch (_) {
        // 깨진 파일도 함께 치운다 — 남겨 두면 매번 실패를 반복한다.
      }
      try {
        file.deleteSync();
      } catch (_) {}
    }
    return items;
  }
}
