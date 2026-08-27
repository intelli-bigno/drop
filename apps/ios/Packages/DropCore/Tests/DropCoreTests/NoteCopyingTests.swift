import Foundation
import Testing

@testable import DropCore

/// 목록 더블탭이 클립보드에 넣는 문자열 (BRU-129).
///
/// UIPasteboard는 UIKit이라 DropCore에 둘 수 없다. 무엇을 넣을지만 여기서 고정한다.
@Suite("노트 복사")
struct NoteCopyingTests {
    private func note(content: String) -> Note {
        let now = Date()
        return Note(
            id: "n1", displayID: 42, content: content,
            createdAt: now, updatedAt: now, source: .mobile
        )
    }

    @Test("클립보드에는 본문만 들어간다")
    func clipboardStringIsContent() {
        let body = "장보기: 우유, 커피 원두"
        #expect(NoteCopying.clipboardString(for: note(content: body)) == body)
    }

    @Test("본문이 비어 있으면 빈 문자열이다")
    func emptyContentCopiesEmptyString() {
        #expect(NoteCopying.clipboardString(for: note(content: "")) == "")
    }

    @Test("참조 링크나 display id는 넣지 않는다")
    func doesNotIncludeReferenceLink() {
        let copied = NoteCopying.clipboardString(for: note(content: "본문만"))
        #expect(copied == "본문만")
        #expect(!copied.contains("drop://"))
        #expect(!copied.contains("42"))
    }

    @Test("선택 모드에서는 더블탭이 복사하지 않는다")
    func selectionModeDoesNotCopy() {
        #expect(NoteCopying.shouldCopyOnDoubleTap(isSelecting: true) == false)
        #expect(NoteCopying.shouldCopyOnDoubleTap(isSelecting: false) == true)
    }
}
