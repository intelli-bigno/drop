/// 목록 행 탭의 라우팅 판정 (BRU-77 · BRU-129).
///
/// iOS `HomeView.handleNoteTap` 대응 — 제스처는 화면 몫이지만 "무엇을 할지"는
/// 순수 함수로 떼어 두어 위젯 트리 없이 검증한다.
library;

import 'package:drop_core/drop_core.dart';

enum NoteTapResult {
  /// 선택 모드에서는 싱글탭·더블탭 모두 토글만 한다.
  toggleSelection,

  /// 더블탭 = 본문 복사 (BRU-129).
  copyContent,

  /// 싱글탭 = 뷰어 열기 (BRU-77). 편집은 뷰어에서 한 번 더 들어가야 한다.
  openViewer,
}

NoteTapResult resolveNoteTap({required bool isSelecting, required int count}) {
  if (isSelecting) return NoteTapResult.toggleSelection;
  if (count == 2 && NoteCopying.shouldCopyOnDoubleTap(isSelecting: false)) {
    return NoteTapResult.copyContent;
  }
  return NoteTapResult.openViewer;
}
