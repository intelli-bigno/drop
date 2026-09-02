/// 딥링크로 들어온 요청을 화면이 집어 갈 때까지 들고 있는다.
/// iOS `Drop/DropRouter.swift` 대응.
///
/// 콜드 스타트에서는 링크가 화면보다 먼저 도착한다. 그래서 즉시 처리하지 않고
/// 보관해 두었다가, 홈이 나타난 뒤에 소비하게 한다.
library;

import 'package:drop_core/drop_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 위젯에서 들어온 사진 첨부 요청 (BRU-43). 카메라·갤러리는 여는 창만 다르고
/// 그 뒤는 앱의 기존 사진 첨부 경로를 그대로 탄다.
enum QuickCapture { camera, gallery }

class DeepLinkRouter extends ChangeNotifier {
  String? _pendingNoteId;
  String? _pendingComposeText;
  QuickCapture? _pendingCapture;

  String? get pendingNoteId => _pendingNoteId;
  String? get pendingComposeText => _pendingComposeText;
  QuickCapture? get pendingCapture => _pendingCapture;

  bool get hasPending =>
      _pendingNoteId != null ||
      _pendingComposeText != null ||
      _pendingCapture != null;

  void handle(DropLink link) {
    switch (link) {
      case NoteLink(:final id):
        _pendingNoteId = id;
      case ComposeLink(:final text):
        _pendingComposeText = text ?? '';
      case CameraLink():
        _pendingCapture = QuickCapture.camera;
      case GalleryLink():
        _pendingCapture = QuickCapture.gallery;
    }
    notifyListeners();
  }

  String? consumeNoteId() {
    final id = _pendingNoteId;
    _pendingNoteId = null;
    return id;
  }

  String? consumeComposeText() {
    final text = _pendingComposeText;
    _pendingComposeText = null;
    return text;
  }

  QuickCapture? consumeCapture() {
    final capture = _pendingCapture;
    _pendingCapture = null;
    return capture;
  }
}

final deepLinkRouterProvider = ChangeNotifierProvider<DeepLinkRouter>(
  (ref) => DeepLinkRouter(),
);
