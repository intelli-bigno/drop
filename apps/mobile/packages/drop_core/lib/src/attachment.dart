import 'drop_json.dart';
import 'storage_path.dart';

/// DB의 `attachments.type`. 서버가 새 종류를 먼저 내보내도 목록이 통째로
/// 깨지지 않도록 `unknown`을 둔다. DropCore `Attachment.swift` 대응.
enum AttachmentType {
  image,
  audio,
  video,
  file,
  text,
  instagram,
  youtube,
  unknown;

  static AttachmentType fromRaw(String raw) => AttachmentType.values
      .firstWhere((v) => v.name == raw && v != unknown, orElse: () => unknown);

  /// 확장자로 종류를 짐작한다. 공유로 들어온 파일은 종류가 함께 오지 않는다.
  static AttachmentType forFileName(String name) {
    final mime = MimeType.forExtension(StoragePath.fileExtension(name) ?? '');
    if (mime.startsWith('image/')) return image;
    if (mime.startsWith('video/')) return video;
    if (mime.startsWith('audio/')) return audio;
    if (mime == 'text/plain') return text;
    return file;
  }
}

class Attachment {
  final String id;
  final String noteId;
  final AttachmentType type;
  final String storagePath;
  final String? filename;
  final String? mimeType;
  final int? size;
  final String? originalUrl;
  final String? authorName;
  final String? authorUrl;
  final String? caption;
  final DateTime createdAt;

  const Attachment({
    required this.id,
    required this.noteId,
    required this.type,
    required this.storagePath,
    this.filename,
    this.mimeType,
    this.size,
    this.originalUrl,
    this.authorName,
    this.authorUrl,
    this.caption,
    required this.createdAt,
  });

  factory Attachment.fromJson(Map<String, Object?> json) => Attachment(
        id: json['id'] as String,
        noteId: json['note_id'] as String,
        type: AttachmentType.fromRaw(json['type'] as String),
        storagePath: json['storage_path'] as String,
        filename: json['filename'] as String?,
        mimeType: json['mime_type'] as String?,
        size: (json['size'] as num?)?.toInt(),
        originalUrl: json['original_url'] as String?,
        authorName: json['author_name'] as String?,
        authorUrl: json['author_url'] as String?,
        caption: json['caption'] as String?,
        createdAt: parsePostgresTimestamp(json['created_at'] as String),
      );

  bool get isImage => type == AttachmentType.image;
  bool get isVideo => type == AttachmentType.video;
  bool get isLink =>
      type == AttachmentType.instagram || type == AttachmentType.youtube;
  bool get isMedia => isImage || isVideo || type == AttachmentType.audio;
  bool get isFile =>
      type == AttachmentType.file || type == AttachmentType.text;

  /// 두 네이티브 앱의 `formattedSize`와 같은 표기를 유지한다.
  String get formattedSize {
    final size = this.size;
    if (size == null) return '';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  bool operator ==(Object other) =>
      other is Attachment &&
      other.id == id &&
      other.noteId == noteId &&
      other.type == type &&
      other.storagePath == storagePath &&
      other.filename == filename &&
      other.mimeType == mimeType &&
      other.size == size &&
      other.originalUrl == originalUrl &&
      other.authorName == authorName &&
      other.authorUrl == authorUrl &&
      other.caption == caption &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, noteId, type, storagePath, filename,
      mimeType, size, originalUrl, authorName, authorUrl, caption, createdAt);

  @override
  String toString() => 'Attachment($id, ${type.name}, $storagePath)';
}
