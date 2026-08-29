import 'attachment.dart';
import 'collection_equality.dart';
import 'drop_json.dart';
import 'tag.dart';

/// 노트를 만든 곳. #21에서 MCP로 만든 노트가 CHECK 제약에 걸린 이력이 있어,
/// 서버가 아직 우리가 모르는 값을 보내도 목록 전체가 깨지지 않도록 `unknown`을 둔다.
/// DropCore `Note.swift` 대응.
enum NoteSource {
  mobile,
  desktop,
  web,
  mcp,
  unknown;

  static NoteSource fromRaw(String raw) => NoteSource.values
      .firstWhere((v) => v.name == raw && v != unknown, orElse: () => unknown);
}

/// 노트의 종류 (BRU-175/BRU-184).
///
/// `note` = 생각·메모·레퍼런스 등 읽고 정리하는 것. `todo` = 그 자체가 할일이라
/// 끝났는지 여부를 갖는 것. 둘 다 노트다 — 목록·검색에서 빠지는 쪽이 없다.
///
/// `NoteSource`와 달리 `unknown` 값을 두지 않는다. 모르는 값이 오면 `note`로
/// 넘어뜨린다 — 알 수 없는 것을 할일로 오인해 체크박스를 그리는 쪽이 더 나쁘다.
enum NoteType {
  note,
  todo;

  static NoteType fromRaw(Object? raw) =>
      NoteType.values.firstWhere((v) => v.name == raw, orElse: () => NoteType.note);
}

/// 목록 화면의 상단 탭.
enum NoteViewMode { active, archived, trash }

/// 목록 화면의 카테고리 필터.
enum NoteCategory { all, links, media, files }

/// 할일 필터 (BRU-184). 데스크톱 `TodoFilter`와 같은 3단 순환이다.
///
/// 카테고리(`NoteCategory`)와 **별도 축**인 이유: 할일이면서 링크가 있는 노트가
/// 있다. 같은 enum에 넣으면 서로 배타가 되어 그런 노트를 표현할 수 없다.
enum TodoFilter {
  /// 걸러내지 않음
  off,

  /// 할일 전부 — 끝난 것도 포함한다. 목록은 "무엇을 했나"까지 보여 주는 것이 쓸모다.
  all,

  /// 아직 끝나지 않은 할일만
  open;

  TodoFilter get next => switch (this) {
        TodoFilter.off => TodoFilter.all,
        TodoFilter.all => TodoFilter.open,
        TodoFilter.open => TodoFilter.off,
      };

  bool matches(Note note) => switch (this) {
        TodoFilter.off => true,
        TodoFilter.all => note.isTodo,
        TodoFilter.open => note.isTodo && !note.isCompleted,
      };
}

/// `replacing`에서 "그대로 두기"와 "비우기"를 구분하기 위한 표식.
class _Unset {
  const _Unset();
}

const _unset = _Unset();

class Note {
  final String id;
  final int displayId;
  final String content;
  final String? parentId;
  final List<Attachment> attachments;
  final List<Tag> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final NoteSource source;
  final DateTime? archivedAt;
  final DateTime? deletedAt;
  final bool isDeleted;
  final bool hasLink;
  final bool hasMedia;
  final bool hasFiles;
  final bool isLocked;
  final bool isPinned;
  final DateTime? pinnedAt;
  final int priority;

  /// 노트의 종류 (BRU-184). 기본은 일반 노트.
  final NoteType type;

  /// 할일을 끝낸 시각. null이면 미완료.
  /// `type`이 `todo`일 때만 채워진다 — DB CHECK(`notes_todo_state_consistent`)가
  /// 일반 노트에 완료 시각이 남는 조합을 거부한다.
  final DateTime? completedAt;

  const Note({
    required this.id,
    required this.displayId,
    required this.content,
    this.parentId,
    this.attachments = const [],
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
    required this.source,
    this.archivedAt,
    this.deletedAt,
    this.isDeleted = false,
    this.hasLink = false,
    this.hasMedia = false,
    this.hasFiles = false,
    this.isLocked = false,
    this.isPinned = false,
    this.pinnedAt,
    this.priority = 0,
    this.type = NoteType.note,
    this.completedAt,
  });

  factory Note.fromJson(Map<String, Object?> json) => Note(
        id: json['id'] as String,
        displayId: (json['display_id'] as num).toInt(),
        // DB에서는 null이 될 수 있지만 화면에서는 항상 문자열이어야 한다.
        content: json['content'] as String? ?? '',
        parentId: json['parent_id'] as String?,
        // 목록 쿼리가 select를 줄이면 관계가 통째로 빠진다 — 없는 것과 빈 것을 같게 본다.
        attachments: (json['attachments'] as List<Object?>? ?? const [])
            .map((row) => Attachment.fromJson(row as Map<String, Object?>))
            .toList(),
        tags: (json['tags'] as List<Object?>? ?? const [])
            .map((row) => Tag.fromJson(row as Map<String, Object?>))
            .toList(),
        createdAt: parsePostgresTimestamp(json['created_at'] as String),
        updatedAt: parsePostgresTimestamp(json['updated_at'] as String),
        source: NoteSource.fromRaw(json['source'] as String),
        archivedAt: parseOptionalPostgresTimestamp(json['archived_at']),
        deletedAt: parseOptionalPostgresTimestamp(json['deleted_at']),
        isDeleted: json['is_deleted'] as bool? ?? false,
        hasLink: json['has_link'] as bool? ?? false,
        hasMedia: json['has_media'] as bool? ?? false,
        hasFiles: json['has_files'] as bool? ?? false,
        isLocked: json['is_locked'] as bool? ?? false,
        isPinned: json['is_pinned'] as bool? ?? false,
        pinnedAt: parseOptionalPostgresTimestamp(json['pinned_at']),
        priority: (json['priority'] as num?)?.toInt() ?? 0,
        // 백필 이전 행이나 아직 갱신되지 않은 RPC 응답이 섞여도 목록이 깨지지
        // 않게 기본값 쪽으로 넘어뜨린다 (BRU-184)
        type: NoteType.fromRaw(json['type']),
        completedAt: parseOptionalPostgresTimestamp(json['completed_at']),
      );

  bool get isReply => parentId != null;

  /// 그 자체가 할일인 노트인가 (BRU-184)
  bool get isTodo => type == NoteType.todo;

  /// 끝난 할일인가.
  ///
  /// 완료 시각만 보지 않고 타입도 함께 본다. DB CHECK가 이미 조합을 막지만,
  /// 제약이 한 겹 뚫려도 일반 노트에 취소선이 그어지는 일은 없어야 한다.
  bool get isCompleted => isTodo && completedAt != null;
  bool get isArchived => archivedAt != null;
  bool get isInTrash => deletedAt != null;
  bool get isActive => !isArchived && !isInTrash;

  bool matchesViewMode(NoteViewMode viewMode) => switch (viewMode) {
        NoteViewMode.active => isActive,
        NoteViewMode.archived => isArchived,
        NoteViewMode.trash => isInTrash,
      };

  bool matchesCategory(NoteCategory category) => switch (category) {
        NoteCategory.all => true,
        NoteCategory.links => hasLink,
        NoteCategory.media => hasMedia,
        NoteCategory.files => hasFiles,
      };

  /// `Note`는 값처럼 다룬다 — 부분 수정에는 새 값을 만든다.
  /// 옵셔널 필드는 "그대로 두기"(인자 생략)와 "비우기"(null 전달)를 구분해야 해서
  /// `_unset` 표식을 기본값으로 쓴다. Swift의 이중 옵셔널 대응.
  Note replacing({
    String? content,
    List<Attachment>? attachments,
    List<Tag>? tags,
    DateTime? updatedAt,
    Object? archivedAt = _unset,
    Object? deletedAt = _unset,
    bool? hasLink,
    bool? hasMedia,
    bool? hasFiles,
    bool? isLocked,
    bool? isPinned,
    Object? pinnedAt = _unset,
    int? priority,
    NoteType? type,
    Object? completedAt = _unset,
  }) {
    final newArchivedAt = identical(archivedAt, _unset)
        ? this.archivedAt
        : archivedAt as DateTime?;
    final newDeletedAt =
        identical(deletedAt, _unset) ? this.deletedAt : deletedAt as DateTime?;
    final newType = type ?? this.type;
    // 일반 노트로 되돌리면 완료 시각도 함께 지운다. DB CHECK가 남은 완료 시각을
    // 거부하므로, 지우지 않으면 이 갱신 자체가 실패한다 — 예외를 던지는 대신
    // "할일이 아니게 되면 완료도 아니다"로 흘려보낸다. 데스크톱 withNoteType과
    // 같은 규칙이다.
    final requestedCompletedAt = identical(completedAt, _unset)
        ? this.completedAt
        : completedAt as DateTime?;
    final newCompletedAt =
        newType == NoteType.todo ? requestedCompletedAt : null;
    return Note(
      id: id,
      displayId: displayId,
      content: content ?? this.content,
      parentId: parentId,
      attachments: attachments ?? this.attachments,
      tags: tags ?? this.tags,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      source: source,
      archivedAt: newArchivedAt,
      deletedAt: newDeletedAt,
      isDeleted: newDeletedAt != null,
      hasLink: hasLink ?? this.hasLink,
      hasMedia: hasMedia ?? this.hasMedia,
      hasFiles: hasFiles ?? this.hasFiles,
      isLocked: isLocked ?? this.isLocked,
      isPinned: isPinned ?? this.isPinned,
      pinnedAt:
          identical(pinnedAt, _unset) ? this.pinnedAt : pinnedAt as DateTime?,
      priority: priority ?? this.priority,
      type: newType,
      completedAt: newCompletedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Note &&
      other.id == id &&
      other.displayId == displayId &&
      other.content == content &&
      other.parentId == parentId &&
      listEquals(other.attachments, attachments) &&
      listEquals(other.tags, tags) &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.source == source &&
      other.archivedAt == archivedAt &&
      other.deletedAt == deletedAt &&
      other.isDeleted == isDeleted &&
      other.hasLink == hasLink &&
      other.hasMedia == hasMedia &&
      other.hasFiles == hasFiles &&
      other.isLocked == isLocked &&
      other.isPinned == isPinned &&
      other.pinnedAt == pinnedAt &&
      other.priority == priority &&
      other.type == type &&
      other.completedAt == completedAt;

  @override
  int get hashCode => Object.hash(
      id,
      displayId,
      content,
      parentId,
      listHash(attachments),
      listHash(tags),
      createdAt,
      updatedAt,
      source,
      archivedAt,
      deletedAt,
      Object.hash(isDeleted, hasLink, hasMedia, hasFiles, isLocked, isPinned,
          pinnedAt, priority, type, completedAt));

  @override
  String toString() => 'Note($id, #$displayId)';
}

/// 남은 할일 수 (BRU-184).
///
/// 끝난 할일은 목록에서는 흐리게 남지만 숫자에서는 빠진다. 숫자는 "얼마나
/// 남았나"에 답해야 하고 목록은 "무엇을 했나"까지 보여 주는 것이 쓸모다 —
/// 두 질문이 다르므로 답도 다르다. 데스크톱 `countOpenTodos`와 같은 규칙.
///
/// 답글은 세지 않는다. 피드는 최상위 노트만 줄로 세우므로 그래야 화면에 보이는
/// 줄 수와 맞는다.
int countOpenTodos(Iterable<Note> notes) =>
    notes.where((n) => !n.isReply && n.isTodo && !n.isCompleted).length;
