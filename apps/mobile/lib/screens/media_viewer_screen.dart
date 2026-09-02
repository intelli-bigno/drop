/// 첨부 전체화면 뷰어. iOS `MediaViewer.swift` 대응.
///
/// 페이지 스와이프로 첨부 사이를 오가고, **더블탭이 닫기**다(BRU-157 완료 조건).
/// iOS는 더블탭을 확대 토글에 쓰지만 Flutter 쪽은 핀치 줌(InteractiveViewer)이
/// 이미 있으므로 더블탭을 닫기에 준다.
///
/// 사진 원본 색을 그대로 보여 주는 것이 목적이라 배경은 중립 검정 — 여기만
/// 팔레트 밖이다 (iOS와 같은 판단).
library;

import 'package:drop_core/drop_core.dart';
import 'package:flutter/material.dart';

import '../widgets/attachment_thumbnail.dart' show AttachmentUrlProvider;

Future<void> showMediaViewer(
  BuildContext context, {
  required List<Attachment> attachments,
  required Attachment current,
  required AttachmentUrlProvider urlProvider,
}) => Navigator.of(context, rootNavigator: true).push(
  MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (context) => MediaViewerScreen(
      attachments: attachments,
      current: current,
      urlProvider: urlProvider,
    ),
  ),
);

class MediaViewerScreen extends StatefulWidget {
  final List<Attachment> attachments;
  final Attachment current;
  final AttachmentUrlProvider urlProvider;

  const MediaViewerScreen({
    super.key,
    required this.attachments,
    required this.current,
    required this.urlProvider,
  });

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen> {
  late final PageController _page = PageController(
    initialPage: widget.attachments
        .indexWhere((attachment) => attachment.id == widget.current.id)
        .clamp(0, widget.attachments.length - 1),
  );
  late Attachment _visible = widget.current;

  /// 썸네일이 이미 받아 둔 서명 URL을 재사용하도록 첨부별로 한 번만 요청한다.
  final Map<String, Future<Uri?>> _urls = {};

  Future<Uri?> _urlFor(Attachment attachment) =>
      _urls.putIfAbsent(attachment.id, () => widget.urlProvider(attachment));

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(_visible.filename ?? '첨부'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('닫기', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: () => Navigator.of(context).pop(),
        child: PageView.builder(
          controller: _page,
          itemCount: widget.attachments.length,
          onPageChanged: (index) =>
              setState(() => _visible = widget.attachments[index]),
          itemBuilder: (context, index) => _pageFor(widget.attachments[index]),
        ),
      ),
    );
  }

  Widget _pageFor(Attachment attachment) => FutureBuilder<Uri?>(
    future: _urlFor(attachment),
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
      }
      final url = snapshot.data;
      if (url == null) return _unavailable();
      if (attachment.isVideo) {
        // 재생은 video_player 의존이 필요하다 — 지금은 자리만 지킨다.
        // 배포 전 실기기 검증(BRU-152 트랙)에서 별도 이슈로 판단한다.
        return _videoPlaceholder(attachment);
      }
      return InteractiveViewer(
        maxScale: 6,
        child: Center(
          child: Image.network(
            url.toString(),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => _unavailable(),
          ),
        ),
      );
    },
  );

  Widget _unavailable() => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.warning_amber_outlined, color: Colors.white54, size: 40),
        SizedBox(height: 8),
        Text('불러오지 못했습니다', style: TextStyle(color: Colors.white70)),
      ],
    ),
  );

  Widget _videoPlaceholder(Attachment attachment) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.play_circle_outline, color: Colors.white70, size: 56),
        const SizedBox(height: 8),
        Text(
          attachment.filename ?? '동영상',
          style: const TextStyle(color: Colors.white70),
        ),
      ],
    ),
  );
}
