import 'dart:typed_data';

import 'attachment.dart';
import 'supabase/supabase_attachments_repository.dart';

var _idCounter = 0;

/// 테스트와 프리뷰용 첨부 리포지토리. 네트워크 없이 같은 계약을 지킨다.
/// 컴포저(BRU-158)의 "만든 뒤 그 id에 붙인다" 경로를 실측하는 데 쓴다.
class InMemoryAttachmentsRepository implements AttachmentsRepository {
  /// 지금까지 올라간 행 전부 — 테스트가 어느 노트에 붙었는지 여기서 확인한다.
  final List<Attachment> attachments = [];

  /// 실패 경로를 시험하기 위한 손잡이.
  Object? uploadError;

  @override
  Future<Attachment> upload({
    required Uint8List data,
    required String fileName,
    required AttachmentType type,
    required String noteId,
  }) async {
    final uploadError = this.uploadError;
    if (uploadError != null) throw uploadError;
    _idCounter += 1;
    final attachment = Attachment(
      id: '첨부-$_idCounter',
      noteId: noteId,
      type: type,
      storagePath: 'memory/$noteId/$_idCounter-$fileName',
      filename: fileName,
      size: data.length,
      createdAt: DateTime.now().toUtc(),
    );
    attachments.add(attachment);
    return attachment;
  }

  @override
  Future<void> delete(Attachment attachment) async {
    attachments.removeWhere((existing) => existing.id == attachment.id);
  }

  @override
  Future<Uri> signedUrl(String storagePath, {int expiresIn = 3600}) async =>
      Uri.parse('memory://$storagePath');
}
