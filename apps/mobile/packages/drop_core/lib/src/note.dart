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

/// 목록 화면의 상단 탭.
enum NoteViewMode { active, archived, trash }

/// 목록 화면의 카테고리 필터.
enum NoteCategory { all, links, media, files }

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
      );

  bool get isReply => parentId != null;
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
  }) {
    final newArchivedAt = identical(archivedAt, _unset)
        ? this.archivedAt
        : archivedAt as DateTime?;
    final newDeletedAt =
        identical(deletedAt, _unset) ? this.deletedAt : deletedAt as DateTime?;
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
      other.priority == priority;

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
          pinnedAt, priority));

  @override
  String toString() => 'Note($id, #$displayId)';
}
