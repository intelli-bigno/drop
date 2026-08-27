import Foundation

/// 목록 더블탭이 클립보드에 넣는 문자열 (BRU-129).
///
/// UIPasteboard는 UIKit이라 DropCore에 둘 수 없다. 무엇을 넣을지만 여기서 정한다.
public enum NoteCopying {
    /// 이번 범위는 본문만. 참조 링크(`drop://note/…`)는 후속.
    public static func clipboardString(for note: Note) -> String {
        note.content
    }

    /// 선택 모드에서는 더블탭도 복사하지 않는다 — 선택은 토글만 한다.
    public static func shouldCopyOnDoubleTap(isSelecting: Bool) -> Bool {
        !isSelecting
    }
}
