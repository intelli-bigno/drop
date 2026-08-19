import Foundation
import Testing

@testable import DropCore

/// 작성 시트 툴바가 부르는 편집 명령. **화면이 아니라 여기가 정본이다** —
/// "어디에 무엇을 끼워 넣고 커서를 어디 두느냐"는 순수 계산이고,
/// 시뮬레이터 없이 검증되어야 툴바를 늘려도 무너지지 않는다 (BRU-37).
@Suite("마크다운 편집 명령")
struct MarkdownEditorTests {
    private func apply(
        _ command: MarkdownEditingCommand,
        to text: String,
        _ selection: NSRange
    ) -> MarkdownEditingResult {
        MarkdownEditor.apply(command, to: text, selection: selection)
    }

    // MARK: - 강조 감싸기

    @Test("고른 글자를 굵게로 감싼다")
    func boldWrapsTheSelection() {
        let result = apply(.bold, to: "hello world", NSRange(location: 6, length: 5))
        #expect(result.text == "hello **world**")
        #expect(result.selection == NSRange(location: 8, length: 5))
    }

    @Test("이미 굵은 글자를 다시 누르면 풀린다")
    func boldOnBoldTextUnwraps() {
        let inner = apply(.bold, to: "**world**", NSRange(location: 2, length: 5))
        #expect(inner.text == "world")
        #expect(inner.selection == NSRange(location: 0, length: 5))

        let outer = apply(.bold, to: "**world**", NSRange(location: 0, length: 9))
        #expect(outer.text == "world")
        #expect(outer.selection == NSRange(location: 0, length: 5))
    }

    @Test("고른 글자가 없으면 기호만 넣고 그 사이에 커서를 둔다")
    func boldWithEmptySelectionParksTheCaretInside() {
        let result = apply(.bold, to: "memo", NSRange(location: 4, length: 0))
        #expect(result.text == "memo****")
        #expect(result.selection == NSRange(location: 6, length: 0))
    }

    @Test("기울임은 별표 하나로 감싼다")
    func italicWrapsWithASingleStar() {
        let result = apply(.italic, to: "hello", NSRange(location: 0, length: 5))
        #expect(result.text == "*hello*")
        #expect(result.selection == NSRange(location: 1, length: 5))
    }

    /// UTF-16 기준으로 세지 않으면 한글·이모지가 섞인 순간 커서가 글자 가운데로 간다.
    @Test("한글과 이모지가 섞여도 자리가 맞는다")
    func offsetsFollowUTF16ForKoreanAndEmoji() {
        let text = "메모 🍊 끝"
        let result = apply(.bold, to: text, NSRange(location: 0, length: 2))
        #expect(result.text == "**메모** 🍊 끝")
        #expect(result.selection == NSRange(location: 2, length: 2))
    }

    // MARK: - 코드

    @Test("한 줄을 고르면 인라인 코드가 된다")
    func codeOnASingleLineIsInline() {
        let result = apply(.code, to: "run make", NSRange(location: 4, length: 4))
        #expect(result.text == "run `make`")
        #expect(result.selection == NSRange(location: 5, length: 4))
    }

    /// 여러 줄에 백틱 하나를 두르면 렌더가 깨진다 — 그 경우는 펜스가 답이다.
    @Test("여러 줄을 고르면 펜스 코드블록이 된다")
    func codeOnMultipleLinesIsFenced() {
        let result = apply(.code, to: "a\nb", NSRange(location: 0, length: 3))
        #expect(result.text == "```\na\nb\n```")
        #expect(result.selection == NSRange(location: 4, length: 3))
    }

    // MARK: - 링크

    @Test("고른 글자가 링크 글자가 되고 주소 자리가 선택된다")
    func linkPutsSelectionIntoTheDestinationSlot() {
        let result = apply(.link, to: "drop", NSRange(location: 0, length: 4))
        #expect(result.text == "[drop](url)")
        #expect(result.selection == NSRange(location: 7, length: 3))
    }

    @Test("고른 글자가 없으면 글자 자리를 먼저 선택한다")
    func linkWithEmptySelectionSelectsTheTextSlot() {
        let result = apply(.link, to: "", NSRange(location: 0, length: 0))
        #expect(result.text == "[텍스트](url)")
        #expect(result.selection == NSRange(location: 1, length: 3))
    }

    // MARK: - 줄 앞머리 — 제목

    @Test("제목은 눌릴 때마다 단계가 깊어진다")
    func headingDeepensOnEachTap() {
        let first = apply(.heading, to: "memo", NSRange(location: 4, length: 0))
        #expect(first.text == "# memo")
        #expect(first.selection == NSRange(location: 6, length: 0))

        #expect(apply(.heading, to: "# memo", NSRange(location: 6, length: 0)).text == "## memo")
    }

    @Test("여섯 단계 다음에는 제목이 풀린다")
    func headingWrapsBackToPlainAfterSix() {
        #expect(apply(.heading, to: "###### memo", NSRange(location: 0, length: 0)).text == "memo")
    }

    // MARK: - 줄 앞머리 — 목록·체크박스·인용

    @Test("불릿은 붙었다 떨어진다")
    func bulletTogglesOnAndOff() {
        let on = apply(.bulletList, to: "memo", NSRange(location: 0, length: 0))
        #expect(on.text == "- memo")
        #expect(apply(.bulletList, to: "- memo", NSRange(location: 0, length: 0)).text == "memo")
    }

    @Test("불릿을 떼면 체크박스까지 함께 떨어진다")
    func bulletRemovesTheWholeTaskMarker() {
        #expect(apply(.bulletList, to: "- [ ] memo", NSRange(location: 0, length: 0)).text == "memo")
    }

    @Test("이미 불릿인 줄에는 체크칸만 끼워 넣는다")
    func checkboxSlotsIntoAnExistingBullet() {
        #expect(apply(.checkbox, to: "- memo", NSRange(location: 0, length: 0)).text == "- [ ] memo")
    }

    @Test("맨 줄에 체크박스를 누르면 불릿까지 붙는다")
    func checkboxOnPlainLineAddsTheBulletToo() {
        #expect(apply(.checkbox, to: "memo", NSRange(location: 0, length: 0)).text == "- [ ] memo")
    }

    @Test("체크박스를 다시 누르면 통째로 떨어진다")
    func checkboxTogglesOff() {
        #expect(apply(.checkbox, to: "- [x] memo", NSRange(location: 0, length: 0)).text == "memo")
    }

    @Test("인용도 붙었다 떨어진다")
    func quoteTogglesOnAndOff() {
        #expect(apply(.quote, to: "memo", NSRange(location: 0, length: 0)).text == "> memo")
        #expect(apply(.quote, to: "> memo", NSRange(location: 0, length: 0)).text == "memo")
    }

    // MARK: - 여러 줄에 걸친 앞머리

    @Test("고른 범위에 걸친 줄 전부에 앞머리가 붙는다")
    func linePrefixAppliesToEveryTouchedLine() {
        let result = apply(.bulletList, to: "a\nb\nc", NSRange(location: 0, length: 3))
        #expect(result.text == "- a\n- b\nc")
    }

    /// 일부만 붙어 있을 때 "떼기"로 판정하면 나머지 줄이 영영 목록이 되지 못한다.
    @Test("전부 붙어 있을 때만 떨어진다")
    func linePrefixOnlyTogglesOffWhenEveryLineHasIt() {
        #expect(apply(.bulletList, to: "- a\nb", NSRange(location: 0, length: 5)).text == "- - a\n- b")
        #expect(apply(.bulletList, to: "- a\n- b", NSRange(location: 0, length: 7)).text == "a\nb")
    }

    @Test("앞머리를 붙여도 고른 글자는 그대로 고른 채 남는다")
    func selectionStillCoversTheSameTextAfterPrefixing() {
        let result = apply(.bulletList, to: "memo", NSRange(location: 0, length: 4))
        #expect(result.text == "- memo")
        #expect(result.selection == NSRange(location: 2, length: 4))
    }

    // MARK: - 원문 보존 (BRU-66)

    /// 명령을 부른 적이 없으면 글자는 한 자도 달라지지 않는다. 미리보기 전환이
    /// 저장 경로를 건드리지 않는다는 불변식의 핵심이 이것이다.
    @Test("명령은 원래 문자열을 바꾸지 않는다")
    func commandsDoNotMutateTheInput() {
        let original = "# 제목\n- [ ] 할 일"
        _ = apply(.bold, to: original, NSRange(location: 0, length: 3))
        #expect(original == "# 제목\n- [ ] 할 일")
    }
}
