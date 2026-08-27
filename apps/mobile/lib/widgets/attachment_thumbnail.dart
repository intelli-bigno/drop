/// 첨부 하나의 썸네일. iOS `AttachmentThumbnail`(DropUI) 대응.
///
/// 비공개 버킷이라 서명 URL을 받아야 그릴 수 있다 — URL을 받는 중이거나
/// 실패하면(프리뷰 포함) 종류 아이콘으로 남는다. 문서·오디오는 뷰어로
/// 넘어가지 않으므로 항상 아이콘이다.
library;

import 'package:drop_core/drop_core.dart';
import 'package:flutter/material.dart';

typedef AttachmentUrlProvider = Future<Uri?> Function(Attachment attachment);

class AttachmentThumbnail extends StatefulWidget {
  final Attachment attachment;
  final double size;
  final AttachmentUrlProvider urlProvider;

  const AttachmentThumbnail({
    super.key,
    required this.attachment,
    required this.urlProvider,
    this.size = 84,
  });

  @override
  State<AttachmentThumbnail> createState() => _AttachmentThumbnailState();
}

class _AttachmentThumbnailState extends State<AttachmentThumbnail> {
  late final Future<Uri?> _url = widget.attachment.isImage
      ? widget.urlProvider(widget.attachment)
      // 이미지가 아니면 URL을 받아도 썸네일로 그릴 수 없다 — 왕복을 아낀다.
      : Future.value(null);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: widget.size,
        height: widget.size,
        color: theme.colorScheme.surfaceContainerHighest,
        child: FutureBuilder<Uri?>(
          future: _url,
          builder: (context, snapshot) {
            final url = snapshot.data;
            if (url == null) return _placeholder(theme);
            return Image.network(
              url.toString(),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _placeholder(theme),
            );
          },
        ),
      ),
    );
  }

  Widget _placeholder(ThemeData theme) => Icon(
        switch (widget.attachment.type) {
          AttachmentType.image => Icons.image_outlined,
          AttachmentType.video => Icons.videocam_outlined,
          AttachmentType.audio => Icons.audiotrack_outlined,
          _ => Icons.description_outlined,
        },
        size: 28,
        color: theme.colorScheme.outline,
      );
}
