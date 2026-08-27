/// 첨부 파일의 저장 경로 규칙. DropCore `StoragePath.swift` 대응.
///
/// **iOS 네이티브와 같은 규칙이어야 한다** — 두 앱이 같은 버킷을 보는 기간이 있어서,
/// 규칙이 갈리면 한쪽에서 올린 파일을 다른 쪽이 못 찾는다.
///   `{user_id}/{note_id}/{고유값}.{확장자}`
library;

import 'dart:math';

class StoragePath {
  StoragePath._();

  static String make({
    required String userId,
    required String noteId,
    required String fileName,
    required String fallbackExtension,
    String? uniqueSuffix,
  }) {
    // 파일명에서 확장자만 취한다. 이름 자체는 경로에 쓰지 않으므로
    // `../` 같은 값이 들어와도 경로를 벗어날 수 없다.
    final ext = fileExtension(fileName) ?? fallbackExtension;
    final suffix = uniqueSuffix ?? newUniqueSuffix();
    return '$userId/$noteId/$suffix.$ext';
  }

  /// `${microsecondsSinceEpoch}_${salt}` 모양 — 두 네이티브 앱과 같다.
  static String newUniqueSuffix() {
    final microseconds = DateTime.now().toUtc().microsecondsSinceEpoch;
    final salt = Random().nextInt(0x100000000);
    return '${microseconds}_$salt';
  }

  static String? fileExtension(String fileName) {
    final lastComponent =
        fileName.contains('/') ? fileName.split('/').last : fileName;
    final dotIndex = lastComponent.lastIndexOf('.');
    if (dotIndex < 0) return null;
    final ext = lastComponent.substring(dotIndex + 1);
    return ext.isEmpty ? null : ext;
  }
}

class MimeType {
  MimeType._();

  static String forExtension(String ext) {
    switch (ext.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'm4a':
        return 'audio/m4a';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'pdf':
        return 'application/pdf';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }
}

class TagName {
  TagName._();

  /// 같은 태그가 대소문자·공백 때문에 둘로 갈라지지 않도록 두 네이티브 앱과
  /// 같은 규칙으로 좁힌다.
  static String? normalized(String raw) {
    final trimmed = raw.trim().toLowerCase();
    return trimmed.isEmpty ? null : trimmed;
  }
}
