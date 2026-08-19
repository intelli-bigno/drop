import Foundation
import Testing

@testable import DropCore

/// 인라인 문법. 블록 파서와 갈라 두는 이유는 하나 — 인라인 규칙은 경계 조건이
/// 많아서(닫히지 않은 마커, 이스케이프, 코드 스팬) 따로 조여야 한다.
@Suite("마크다운 파서 — 인라인")
struct MarkdownInlineTests {
    private let parser = MarkdownParser()

    /// 문단 하나로 감싸 인라인 결과만 꺼낸다.
    private func inlines(_ source: String) -> [MarkdownInline] {
        guard case let .paragraph(content)? = parser.parse(source).blocks.first else { return [] }
        return content
    }

    // MARK: - 강조

    @Test("**과 __는 굵게다")
    func doubleMarkersAreStrong() {
        #expect(inlines("앞 **굵게** 뒤") == [.text("앞 "), .strong([.text("굵게")]), .text(" 뒤")])
        #expect(inlines("__굵게__") == [.strong([.text("굵게")])])
    }

    @Test("*과 _는 기울임이다")
    func singleMarkersAreEmphasis() {
        #expect(inlines("*기울임*") == [.emphasis([.text("기울임")])])
        #expect(inlines("_기울임_") == [.emphasis([.text("기울임")])])
    }

    /// `snake_case_name`이 기울임이 되면 코드 이름을 적은 노트가 전부 뭉개진다.
    @Test("단어 안의 _는 기울임이 아니다")
    func intrawordUnderscoreIsLiteral() {
        #expect(inlines("snake_case_name") == [.text("snake_case_name")])
    }

    @Test("굵게 안에 기울임이 들어간다")
    func strongCanContainEmphasis() {
        #expect(inlines("**굵고 *기울고***") == [
            .strong([.text("굵고 "), .emphasis([.text("기울고")])]),
        ])
    }

    @Test("닫히지 않은 마커는 글자 그대로다")
    func unclosedMarkerStaysLiteral() {
        #expect(inlines("**닫지 않음") == [.text("**닫지 않음")])
        #expect(inlines("한 개 * 별") == [.text("한 개 * 별")])
    }

    // MARK: - 코드 스팬

    @Test("백틱 사이는 인라인 코드다")
    func backticksMakeInlineCode() {
        #expect(inlines("값은 `let x = 1` 이다") == [
            .text("값은 "), .code("let x = 1"), .text(" 이다"),
        ])
    }

    @Test("코드 스팬 안의 마크업은 글자 그대로다")
    func markupInsideCodeSpanIsLiteral() {
        #expect(inlines("`**굵지 않다**`") == [.code("**굵지 않다**")])
    }

    // MARK: - 링크

    @Test("[텍스트](주소)는 링크다")
    func bracketParenIsLink() {
        #expect(inlines("[드롭](https://drop.example)") == [
            .link(content: [.text("드롭")], destination: "https://drop.example"),
        ])
    }

    @Test("링크 글자 안의 강조도 산다")
    func linkTextKeepsItsEmphasis() {
        #expect(inlines("[**굵은 링크**](https://x)") == [
            .link(content: [.strong([.text("굵은 링크")])], destination: "https://x"),
        ])
    }

    @Test("주소 뒤의 제목은 버린다")
    func linkTitleIsDropped() {
        #expect(inlines("[글](https://x \"제목\")") == [
            .link(content: [.text("글")], destination: "https://x"),
        ])
    }

    @Test("괄호가 없으면 링크가 아니다")
    func bracketWithoutParenIsLiteral() {
        #expect(inlines("[그냥 대괄호]") == [.text("[그냥 대괄호]")])
    }

    // MARK: - 이스케이프

    @Test("역슬래시는 다음 기호를 글자로 만든다")
    func backslashEscapesTheNextMark() {
        #expect(inlines("\\*별표\\*") == [.text("*별표*")])
        #expect(inlines("2 \\* 3") == [.text("2 * 3")])
    }

    /// 강조가 아닌 곳의 역슬래시까지 먹어 버리면 윈도우 경로가 사라진다.
    @Test("기호가 아닌 글자 앞의 역슬래시는 남는다")
    func backslashBeforePlainCharacterSurvives() {
        #expect(inlines("C:\\Users") == [.text("C:\\Users")])
    }
}
