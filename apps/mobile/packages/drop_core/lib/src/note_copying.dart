import 'note.dart';

/// 목록 더블탭이 클립보드에 넣는 문자열 (BRU-129).
/// DropCore `NoteCopying.swift` 대응.
///
/// 클립보드 자체는 플랫폼(Flutter) 몫이라 drop_core에 둘 수 없다.
/// 무엇을 넣을지만 여기서 정한다.
class NoteCopying {
  NoteCopying._();

  /// 이번 범위는 본문만. 참조 링크(`drop://note/…`)는 후속.
  static String clipboardString(Note note) => note.content;

  /// 선택 모드에서는 더블탭도 복사하지 않는다 — 선택은 토글만 한다.
  static bool shouldCopyOnDoubleTap({required bool isSelecting}) => !isSelecting;
}
