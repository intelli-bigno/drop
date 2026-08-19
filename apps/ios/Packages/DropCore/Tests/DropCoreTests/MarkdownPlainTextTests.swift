import Foundation
import Testing

@testable import DropCore

/// 목록 한 줄 행(BRU-49)에 붙일 평문. 카드에 원문을 그대로 태우면 `## 제목`이
/// `##`째로 보인다 — 한 줄만 보이는 자리에서는 기호가 정보의 절반을 먹는다.
@Suite("마크다운 평문화")
struct MarkdownPlainTextTests {
    private let parser = MarkdownParser()

    private func plain(_ source: String) -> String {
        parser.parse(source).plainText
    }

    private func summary(_ source: String) -> String {
        parser.parse(source).singleLineSummary
    }

    @Test("제목 기호는 사라지고 글자만 남는다")
    func headingMarksAreStripped() {
        #expect(plain("## 오늘 할 일") == "오늘 할 일")
    }

    @Test("강조·코드·링크 기호가 사라진다")
    func inlineMarksAreStripped() {
        #expect(plain("**굵게** *기울임* `코드` [링크](https://x)") == "굵게 기울임 코드 링크")
    }

    @Test("체크박스는 글자 표식으로 바뀐다")
    func checkboxBecomesTextMarker() {
        #expect(plain("- [ ] 할 일\n- [x] 한 일") == "☐ 할 일\n☑ 한 일")
    }

    @Test("불릿과 번호는 남는다")
    func listMarkersSurviveAsText() {
        #expect(plain("- 하나\n2. 둘") == "• 하나\n2. 둘")
    }

    @Test("인용은 글자만 남는다")
    func quoteKeepsOnlyItsText() {
        #expect(plain("> 인용문") == "인용문")
    }

    @Test("코드블록은 내용만 남는다")
    func codeBlockKeepsOnlyItsBody() {
        #expect(plain("```swift\nlet x = 1\n```") == "let x = 1")
    }

    // MARK: - 한 줄 요약

    @Test("한 줄 요약은 줄바꿈을 공백으로 접는다")
    func summaryFoldsNewlinesIntoSpaces() {
        #expect(summary("# 제목\n\n본문 첫 줄\n둘째 줄") == "제목 본문 첫 줄 둘째 줄")
    }

    @Test("한 줄 요약은 앞뒤 공백을 남기지 않는다")
    func summaryIsTrimmed() {
        #expect(summary("\n\n   # 제목   \n\n") == "제목")
    }

    @Test("빈 노트의 요약은 빈 문자열이다")
    func emptyNoteSummarizesToEmptyString() {
        #expect(summary("") == "")
        #expect(summary("   \n  ") == "")
    }
}
