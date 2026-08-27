import 'dart:math';
import 'dart:typed_data';

import 'attachment.dart';

/// 작성 시트에서 고른 파일. 노트 id가 생기기 전에는 여기에만 있다 (BRU-131).
/// DropCore `ComposerMedia.swift` 대응.
class PendingAttachment {
  final String id;
  final Uint8List data;
  final String fileName;
  final AttachmentType type;

  PendingAttachment({
    String? id,
    required this.data,
    required this.fileName,
    required this.type,
  }) : id = id ?? _randomId();

  static String _randomId() {
    final random = Random();
    return List.generate(4, (_) => random.nextInt(0x10000).toRadixString(16))
        .join('-');
  }
}

/// 고른 미디어가 어느 노트에 붙는지.
///
/// 홈의 사진 선택기는 빈 노트를 새로 만들고 붙인다. 편집 시트는
/// 지금 고치고 있는 그 노트에 붙여야 한다 — 새 display_id가 생기면 안 된다.
sealed class ComposerAttachmentDestination {
  const ComposerAttachmentDestination();

  /// 이미 있는 노트. 업로드는 이 id로 간다.
  const factory ComposerAttachmentDestination.existing({required String noteId}) =
      ExistingNoteDestination;

  /// 아직 id가 없다. 노트를 만든 뒤에 그 id로 붙인다.
  const factory ComposerAttachmentDestination.createThenAttach() =
      CreateThenAttachDestination;
}

class ExistingNoteDestination extends ComposerAttachmentDestination {
  final String noteId;

  const ExistingNoteDestination({required this.noteId});

  @override
  bool operator ==(Object other) =>
      other is ExistingNoteDestination && other.noteId == noteId;

  @override
  int get hashCode => noteId.hashCode;
}

class CreateThenAttachDestination extends ComposerAttachmentDestination {
  const CreateThenAttachDestination();

  @override
  bool operator ==(Object other) => other is CreateThenAttachDestination;

  @override
  int get hashCode => (CreateThenAttachDestination).hashCode;
}

class ComposerAttachmentRouting {
  ComposerAttachmentRouting._();

  static ComposerAttachmentDestination destination({String? editingNoteId}) {
    if (editingNoteId != null) {
      return ComposerAttachmentDestination.existing(noteId: editingNoteId);
    }
    return const ComposerAttachmentDestination.createThenAttach();
  }

  /// 업로드에 쓸 노트 id. 새 노트인데 아직 안 만들어졌으면 null.
  static String? noteIdToAttach({
    required ComposerAttachmentDestination destination,
    String? createdNoteId,
  }) =>
      switch (destination) {
        ExistingNoteDestination(:final noteId) => noteId,
        CreateThenAttachDestination() => createdNoteId,
      };
}
