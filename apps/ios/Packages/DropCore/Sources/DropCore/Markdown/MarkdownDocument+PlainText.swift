import Foundation

public extension MarkdownDocument {
    /// 문법 기호를 걷어낸 글자.
    ///
    /// 목록 한 줄 행(BRU-49)처럼 서식을 그릴 수 없는 자리에 쓴다. 원문을 그대로
    /// 태우면 `## 제목`이 `##`째로 보이는데, 한 줄만 보이는 자리에서는 기호가
    /// 읽을 수 있는 정보의 절반을 먹는다.
    var plainText: String {
        MarkdownDocument.plainText(of: blocks).joined(separator: "\n")
    }

    /// 줄바꿈과 잇단 공백까지 접어 한 줄로 만든 글자.
    var singleLineSummary: String {
        plainText.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func plainText(of blocks: [MarkdownBlock]) -> [String] {
        blocks.flatMap { block -> [String] in
            switch block {
            case let .heading(_, content):
                [plainText(of: content)]
            case let .paragraph(content):
                [plainText(of: content)]
            case let .list(items):
                items.map { item in
                    String(repeating: " ", count: item.indent * 2) + marker(for: item) + plainText(of: item.content)
                }
            case let .codeBlock(_, code):
                [code]
            case let .quote(inner):
                plainText(of: inner)
            case .thematicBreak:
                // 줄 하나를 통째로 먹으면서 글자는 하나도 없다 — 요약에서는 없는 편이 낫다.
                []
            }
        }
    }

    private static func marker(for item: MarkdownListItem) -> String {
        if let checked = item.checked { return checked ? "☑ " : "☐ " }
        if let ordinal = item.ordinal { return "\(ordinal). " }
        return "• "
    }

    private static func plainText(of inlines: [MarkdownInline]) -> String {
        inlines.map { inline in
            switch inline {
            case let .text(value): value
            case let .strong(content): plainText(of: content)
            case let .emphasis(content): plainText(of: content)
            case let .code(value): value
            case let .link(content, _): plainText(of: content)
            }
        }.joined()
    }
}
