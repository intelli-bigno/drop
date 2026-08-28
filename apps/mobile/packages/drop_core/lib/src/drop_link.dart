/// 앱이 알아듣는 링크. DropCore `DropLink.swift` 대응.
///
/// `parse`가 null이면 다른 처리기(Google 로그인 콜백 등)로 넘어간다 —
/// 여기서 전부 삼키면 로그인이 끊긴다.
library;

sealed class DropLink {
  const DropLink();

  /// 위젯이 여는 링크. 앱의 기존 작성 경로를 그대로 탄다 —
  /// 위젯 전용 라우팅을 따로 만들면 두 경로가 어긋난다.
  static final Uri quickComposeUri = Uri.parse('drop://compose');

  /// 카메라·갤러리 바로가기. 앱의 기존 사진 첨부 경로를 그대로 탄다.
  /// 녹음(`drop://record`)은 만들지 않는다 — 기능 자체가 BRU-48에서 없어졌다.
  static final Uri cameraUri = Uri.parse('drop://camera');
  static final Uri galleryUri = Uri.parse('drop://gallery');

  /// 위젯에서 특정 노트를 여는 링크.
  static Uri noteUri(String id) =>
      Uri.tryParse('drop://note/$id') ?? quickComposeUri;

  /// 우리가 아는 링크면 해석하고, 아니면 null.
  static DropLink? parse(Uri url) {
    final scheme = url.scheme.toLowerCase();
    final pathSegments =
        url.pathSegments.where((segment) => segment.isNotEmpty).toList();

    final List<String> segments;
    switch (scheme) {
      case 'drop':
        // drop://note/ID 에서는 "note"가 host 자리에 온다.
        segments = [
          if (url.host.isNotEmpty) url.host,
          ...pathSegments,
        ];
      case 'http' || 'https':
        // 웹 링크는 host가 도메인이므로 경로만 본다.
        if (!url.host.endsWith('intellieffect.com')) return null;
        segments = pathSegments;
      default:
        return null;
    }

    switch (segments.firstOrNull) {
      case 'note':
        if (segments.length < 2 || segments[1].isEmpty) return null;
        return NoteLink(segments[1]);
      case 'compose':
        return ComposeLink(url.queryParameters['text']);
      case 'camera':
        return const CameraLink();
      case 'gallery':
        return const GalleryLink();
      default:
        return null;
    }
  }
}

class NoteLink extends DropLink {
  final String id;

  const NoteLink(this.id);

  @override
  bool operator ==(Object other) => other is NoteLink && other.id == id;

  @override
  int get hashCode => Object.hash(NoteLink, id);
}

class ComposeLink extends DropLink {
  final String? text;

  const ComposeLink([this.text]);

  @override
  bool operator ==(Object other) => other is ComposeLink && other.text == text;

  @override
  int get hashCode => Object.hash(ComposeLink, text);
}

class CameraLink extends DropLink {
  const CameraLink();

  @override
  bool operator ==(Object other) => other is CameraLink;

  @override
  int get hashCode => (CameraLink).hashCode;
}

class GalleryLink extends DropLink {
  const GalleryLink();

  @override
  bool operator ==(Object other) => other is GalleryLink;

  @override
  int get hashCode => (GalleryLink).hashCode;
}
