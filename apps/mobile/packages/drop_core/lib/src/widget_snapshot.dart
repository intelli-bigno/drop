/// 앱이 홈 화면 위젯에게 넘기는 요약. DropCore `WidgetSnapshot.swift` 대응.
///
/// 위젯 확장(Swift)은 Supabase에 접속하지 않는다 — 세션이 없을 수도 있고
/// 메모리 한도도 좁다. 앱이 노트를 불러올 때마다 이 스냅샷을 App Group에
/// 적어 두고, 위젯은 그것만 읽는다. 읽는 쪽은 `ios/DropShell/DropShellCore.swift`
/// — snake_case 키·ISO8601 시각 표기가 이쪽 계약이다.
library;

import 'dart:convert';
import 'dart:io';

import 'collection_equality.dart';
import 'drop_json.dart';
import 'note.dart';

/// 위젯 한 줄에 들어가는 노트.
///
/// `Note`를 그대로 싣지 않는 이유는 둘이다: 첨부·태그까지 App Group 파일에 복사할
/// 이유가 없고, 필드가 바뀔 때마다 위젯이 못 읽는 옛 파일을 만들게 된다.
/// 위젯이 실제로 그리는 것만 담는다.
class WidgetNote {
  final String id;

  /// 이미 한 줄로 접히고 잘린 상태. 위젯 쪽에서 더 손대지 않는다.
  final String excerpt;
  final DateTime createdAt;

  const WidgetNote({
    required this.id,
    required this.excerpt,
    required this.createdAt,
  });

  factory WidgetNote.fromJson(Map<String, Object?> json) => WidgetNote(
        id: json['id'] as String,
        excerpt: json['excerpt'] as String,
        createdAt: parsePostgresTimestamp(json['created_at'] as String),
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'excerpt': excerpt,
        'created_at': formatPostgresTimestamp(createdAt),
      };

  @override
  bool operator ==(Object other) =>
      other is WidgetNote &&
      other.id == id &&
      other.excerpt == excerpt &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, excerpt, createdAt);
}

class WidgetSnapshot {
  /// 작은 위젯에 실제로 보이는 줄 수.
  static const maximumNoteCount = 3;

  /// 말줄임표를 포함한 발췌 최대 길이.
  static const excerptLimit = 80;

  /// 본문이 빈 노트(사진만 붙인 노트 등)를 대신하는 문구.
  static const emptyContentPlaceholder = '(내용 없음)';

  /// 앱이 아직 한 번도 쓰지 않았거나 파일이 깨졌을 때의 값.
  static final empty =
      WidgetSnapshot(notes: const [], generatedAt: DateTime.utc(1));

  final List<WidgetNote> notes;
  final DateTime generatedAt;

  const WidgetSnapshot({required this.notes, required this.generatedAt});

  /// 앱이 들고 있는 노트 목록에서 위젯용 요약을 만든다.
  factory WidgetSnapshot.fromNotes(
    List<Note> notes, {
    DateTime? generatedAt,
  }) {
    final sorted = notes.where((note) => note.isActive).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return WidgetSnapshot(
      notes: [
        for (final note in sorted.take(maximumNoteCount))
          WidgetNote(
            id: note.id,
            excerpt: excerpt(note.content),
            createdAt: note.createdAt,
          ),
      ],
      generatedAt: generatedAt ?? DateTime.now().toUtc(),
    );
  }

  factory WidgetSnapshot.fromJson(Map<String, Object?> json) => WidgetSnapshot(
        notes: [
          for (final note in json['notes'] as List<Object?>? ?? [])
            WidgetNote.fromJson(note as Map<String, Object?>),
        ],
        generatedAt: parsePostgresTimestamp(json['generated_at'] as String),
      );

  Map<String, Object?> toJson() => {
        'notes': [for (final note in notes) note.toJson()],
        'generated_at': formatPostgresTimestamp(generatedAt),
      };

  bool get isEmpty => notes.isEmpty;

  /// 본문을 위젯 한 줄에 맞게 접고 자른다.
  ///
  /// 길이는 룬(코드포인트) 단위 — Swift는 그래핌 단위지만 한글·라틴 범위에서는
  /// 같고, 위젯 발췌 한 줄에서 그 차이는 화면에 드러나지 않는다.
  static String excerpt(String content) {
    final flattened = content
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .join(' ');

    if (flattened.isEmpty) return emptyContentPlaceholder;
    final runes = flattened.runes.toList();
    if (runes.length <= excerptLimit) return flattened;
    return '${String.fromCharCodes(runes.take(excerptLimit - 1))}…';
  }

  @override
  bool operator ==(Object other) =>
      other is WidgetSnapshot &&
      listEquals(other.notes, notes) &&
      other.generatedAt == generatedAt;

  @override
  int get hashCode => Object.hash(listHash(notes), generatedAt);
}

/// 스냅샷이 오가는 App Group 파일 하나 — **적는 쪽**. 읽는 쪽은 위젯(Swift)이다.
class WidgetSnapshotStore {
  /// 공유 수신함과 같은 그룹을 쓴다 — 새 그룹은 포털 수작업을 부른다
  /// (공개 API에 App Group 엔드포인트가 없다).
  static const appGroupId = 'group.com.intellieffect.drop.shared';

  /// App Group 컨테이너 루트의 `widget-snapshot.json`.
  final File file;

  WidgetSnapshotStore(Directory containerDirectory)
      : file = File('${containerDirectory.path}/widget-snapshot.json');

  void write(WidgetSnapshot snapshot) {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(jsonEncode(snapshot.toJson()));
  }

  /// 읽기는 실패하지 않는다. 파일이 없든 깨졌든 위젯은 빈 상태로라도 그려져야 한다.
  WidgetSnapshot read() {
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      return WidgetSnapshot.fromJson(decoded as Map<String, Object?>);
    } catch (_) {
      return WidgetSnapshot.empty;
    }
  }
}
