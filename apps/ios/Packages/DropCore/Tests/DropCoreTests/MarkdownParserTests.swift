import Foundation
import Testing

@testable import DropCore

/// 블록 문법 파서. 화면도 시뮬레이터도 없이 검증한다 — 마크다운 렌더가
/// `AttributedString(markdown:)`이 아니라 DropCore의 파서인 이유가 이것이다 (BRU-37).
@Suite("마크다운 파서 — 블록")
struct MarkdownParserTests {
    private let parser = MarkdownParser()

    private func blocks(_ source: String) -> [MarkdownBlock] {
        parser.parse(source).blocks
    }

    // MARK: - 원문 보존 (BRU-66)

    /// **이 파서는 렌더링만 한다.** 원문을 손대는 순간 "열람했더니 내용이 바뀌었다"가
    /// 되고, 그것이 BRU-66에서 실제로 일어난 사고다. 어떤 입력이 들어와도
    /// `source`는 넣은 그대로여야 한다.
    @Test("파싱은 원문을 그대로 들고 있는다")
    func parsingPreservesSourceVerbatim() {
        let samples = [
            "",
            "  ",
            "# 제목\n\n본문",
            "- [ ] 할 일\n- [x] 한 일",
            "```swift\nlet x = 1\n```",
            "> 인용\n> 계속",
            "닫히지 않은 **굵게",
            "\r\n윈도우 줄바꿈\r\n",
            "이모지 🍊 와 한글",
        ]
        for sample in samples {
            #expect(parser.parse(sample).source == sample)
        }
    }

    // MARK: - 문단

    @Test("빈 입력에는 블록이 없다")
    func emptyInputHasNoBlocks() {
        #expect(blocks("").isEmpty)
        #expect(blocks("\n\n   \n").isEmpty)
    }

    @Test("평범한 줄은 문단이 된다")
    func plainLineBecomesParagraph() {
        #expect(blocks("그냥 메모") == [.paragraph([.text("그냥 메모")])])
    }

    /// 노트 앱이라 사용자가 넣은 줄바꿈은 그대로 보여 준다 — CommonMark의
    /// "소프트 줄바꿈은 공백" 규칙을 따르면 손으로 나눈 줄이 뭉개진다.
    @Test("문단 안의 줄바꿈은 유지된다")
    func paragraphKeepsSoftLineBreaks() {
        #expect(blocks("첫 줄\n둘째 줄") == [.paragraph([.text("첫 줄\n둘째 줄")])])
    }

    @Test("빈 줄은 문단을 가른다")
    func blankLineSplitsParagraphs() {
        #expect(blocks("앞\n\n뒤") == [.paragraph([.text("앞")]), .paragraph([.text("뒤")])])
    }

    // MARK: - 제목

    @Test("# 개수가 제목 단계다")
    func hashCountIsHeadingLevel() {
        for level in 1 ... 6 {
            let source = String(repeating: "#", count: level) + " 제목"
            #expect(blocks(source) == [.heading(level: level, content: [.text("제목")])])
        }
    }

    /// `#태그`를 제목으로 읽으면 DROP의 태그 표기가 전부 제목이 된다.
    @Test("# 뒤에 공백이 없으면 제목이 아니다")
    func hashWithoutSpaceIsNotHeading() {
        #expect(blocks("#태그") == [.paragraph([.text("#태그")])])
    }

    @Test("#이 일곱 개면 제목이 아니다")
    func sevenHashesIsNotHeading() {
        #expect(blocks("####### 너무 깊다") == [.paragraph([.text("####### 너무 깊다")])])
    }

    @Test("제목은 앞뒤 빈 줄 없이도 문단과 갈린다")
    func headingSplitsWithoutBlankLine() {
        #expect(blocks("# 제목\n본문") == [
            .heading(level: 1, content: [.text("제목")]),
            .paragraph([.text("본문")]),
        ])
    }

    // MARK: - 목록

    @Test("-, *, + 는 모두 불릿 목록이다")
    func allBulletMarkersMakeLists() {
        for marker in ["-", "*", "+"] {
            #expect(blocks("\(marker) 항목") == [.list([
                MarkdownListItem(indent: 0, ordinal: nil, checked: nil, content: [.text("항목")]),
            ])])
        }
    }

    @Test("1. 과 1) 은 순서 목록이고 번호를 지킨다")
    func orderedListKeepsItsNumbers() {
        #expect(blocks("3. 셋\n4) 넷") == [.list([
            MarkdownListItem(indent: 0, ordinal: 3, checked: nil, content: [.text("셋")]),
            MarkdownListItem(indent: 0, ordinal: 4, checked: nil, content: [.text("넷")]),
        ])])
    }

    @Test("들여쓴 항목은 단계가 깊어진다")
    func indentationNestsItems() {
        #expect(blocks("- 위\n  - 아래\n    - 더 아래") == [.list([
            MarkdownListItem(indent: 0, ordinal: nil, checked: nil, content: [.text("위")]),
            MarkdownListItem(indent: 1, ordinal: nil, checked: nil, content: [.text("아래")]),
            MarkdownListItem(indent: 2, ordinal: nil, checked: nil, content: [.text("더 아래")]),
        ])])
    }

    @Test("연속한 목록 줄은 한 블록으로 묶인다")
    func consecutiveItemsFormOneList() {
        #expect(blocks("- 하나\n- 둘").count == 1)
        #expect(blocks("- 하나\n\n- 둘").count == 2)
    }

    // MARK: - 체크박스

    @Test("[ ] 와 [x] 는 체크 상태가 된다")
    func taskMarkersBecomeCheckedState() {
        #expect(blocks("- [ ] 할 일\n- [x] 한 일\n- [X] 한 일") == [.list([
            MarkdownListItem(indent: 0, ordinal: nil, checked: false, content: [.text("할 일")]),
            MarkdownListItem(indent: 0, ordinal: nil, checked: true, content: [.text("한 일")]),
            MarkdownListItem(indent: 0, ordinal: nil, checked: true, content: [.text("한 일")]),
        ])])
    }

    @Test("목록이 아닌 줄의 [ ] 는 체크박스가 아니다")
    func bracketsOutsideListAreNotCheckboxes() {
        #expect(blocks("[ ] 그냥 대괄호") == [.paragraph([.text("[ ] 그냥 대괄호")])])
    }

    // MARK: - 코드블록

    @Test("펜스 코드블록은 언어와 내용을 그대로 담는다")
    func fencedCodeBlockKeepsLanguageAndBody() {
        #expect(blocks("```swift\nlet x = 1\n\nlet y = 2\n```") == [
            .codeBlock(language: "swift", code: "let x = 1\n\nlet y = 2"),
        ])
    }

    @Test("언어 표시가 없어도 코드블록이다")
    func fencedCodeBlockWithoutLanguage() {
        #expect(blocks("```\nplain\n```") == [.codeBlock(language: nil, code: "plain")])
    }

    /// 사용자가 아직 닫지 않은 채 미리보기를 켤 수 있다 — 그때 나머지 글이
    /// 통째로 사라지면 안 된다.
    @Test("닫히지 않은 펜스는 끝까지 코드블록이다")
    func unclosedFenceRunsToEnd() {
        #expect(blocks("```\n아직 쓰는 중") == [.codeBlock(language: nil, code: "아직 쓰는 중")])
    }

    @Test("코드블록 안의 마크다운 기호는 문법이 아니다")
    func markupInsideCodeBlockIsLiteral() {
        #expect(blocks("```\n# 제목이 아니다\n- 목록도 아니다\n```") == [
            .codeBlock(language: nil, code: "# 제목이 아니다\n- 목록도 아니다"),
        ])
    }

    // MARK: - 인용

    @Test("> 로 시작하는 줄은 인용이다")
    func angleBracketLineIsQuote() {
        #expect(blocks("> 인용문") == [.quote([.paragraph([.text("인용문")])])])
    }

    /// 인용은 블록을 다시 품는다 — 안에 목록이나 제목이 들어가면 그대로 살아야 한다.
    @Test("인용 안에도 블록이 산다")
    func quoteContainsBlocks() {
        #expect(blocks("> # 제목\n> - 항목") == [.quote([
            .heading(level: 1, content: [.text("제목")]),
            .list([MarkdownListItem(indent: 0, ordinal: nil, checked: nil, content: [.text("항목")])]),
        ])])
    }

    // MARK: - 수평선

    @Test("---, ***, ___ 는 수평선이다")
    func threeRepeatedMarksAreThematicBreak() {
        for source in ["---", "***", "___", "- - -", "*****"] {
            #expect(blocks(source) == [.thematicBreak], "\(source)")
        }
    }

    @Test("두 개짜리는 수평선이 아니다")
    func twoMarksAreNotThematicBreak() {
        #expect(blocks("--") == [.paragraph([.text("--")])])
    }

    // MARK: - 줄바꿈 표기

    @Test("CRLF도 같은 결과를 낸다")
    func carriageReturnsAreNormalized() {
        #expect(blocks("# 제목\r\n\r\n본문") == blocks("# 제목\n\n본문"))
    }
}
