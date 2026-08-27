import 'dart:typed_data';

import '../attachment.dart';
import '../repository_error.dart';
import '../storage_path.dart';
import 'insert_payloads.dart';
import 'supabase_rest.dart';

/// 첨부 데이터 접근 경계. DropCore `AttachmentsRepository.swift` 대응.
abstract interface class AttachmentsRepository {
  /// 파일을 스토리지에 올리고 `attachments` 행을 만든다.
  Future<Attachment> upload({
    required Uint8List data,
    required String fileName,
    required AttachmentType type,
    required String noteId,
  });

  Future<void> delete(Attachment attachment);

  /// 비공개 버킷이라 화면에 띄우려면 서명 URL이 필요하다.
  Future<Uri> signedUrl(String storagePath, {int expiresIn = 3600});
}

class SupabaseAttachmentsRepository implements AttachmentsRepository {
  static const _bucket = 'attachments';

  final SupabaseRestClient client;

  SupabaseAttachmentsRepository({required this.client});

  @override
  Future<Attachment> upload({
    required Uint8List data,
    required String fileName,
    required AttachmentType type,
    required String noteId,
  }) async {
    final userId = client.session.currentUserId;
    if (userId == null) throw const NotesRepositoryError.notAuthenticated();

    final fallbackExtension = _fallbackExtension(type);
    final storagePath = StoragePath.make(
      userId: userId,
      noteId: noteId,
      fileName: fileName,
      fallbackExtension: fallbackExtension,
    );
    final mimeType = MimeType.forExtension(
      StoragePath.fileExtension(fileName) ?? fallbackExtension,
    );

    await client.storageUpload(
      bucket: _bucket,
      path: storagePath,
      data: data,
      contentType: mimeType,
    );

    // 스토리지에는 올라갔는데 행 생성이 실패하면 고아 파일이 남는다.
    // 그 경우 올린 파일을 되돌려 두 저장소가 어긋난 채로 남지 않게 한다.
    try {
      final row = await client.insertReturning(
        'attachments',
        attachmentInsertPayload(
          noteId: noteId,
          type: type.name,
          storagePath: storagePath,
          filename: fileName,
          mimeType: mimeType,
          size: data.length,
        ),
      );
      return client.run(() async => Attachment.fromJson(row));
    } catch (_) {
      await client.storageRemoveQuietly(bucket: _bucket, path: storagePath);
      rethrow;
    }
  }

  @override
  Future<void> delete(Attachment attachment) async {
    await client.delete('attachments', filters: {'id': 'eq.${attachment.id}'});
    // 행이 지워졌으면 파일도 지운다. 실패해도 목록에는 이미 안 보이므로
    // 사용자 흐름을 막지 않는다.
    await client.storageRemoveQuietly(
        bucket: _bucket, path: attachment.storagePath);
  }

  @override
  Future<Uri> signedUrl(String storagePath, {int expiresIn = 3600}) =>
      client.storageSignedUrl(
          bucket: _bucket, path: storagePath, expiresIn: expiresIn);

  static String _fallbackExtension(AttachmentType type) => switch (type) {
        AttachmentType.audio => 'm4a',
        AttachmentType.image => 'png',
        AttachmentType.video => 'mp4',
        _ => 'bin',
      };
}
