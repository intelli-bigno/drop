import DropCore
import SwiftUI

/// 마크다운 본문 렌더. 문법 해석은 전부 `DropCore`의 `MarkdownParser`가 하고
/// 여기는 그 결과를 그리기만 한다 (BRU-37).
///
/// **읽기 전용이다.** 체크박스도 눌리지 않는다 — 열람 화면에서 무엇이든 눌러
/// 본문이 바뀌는 길을 만들면 그것이 곧 BRU-66이다. 체크는 편집기에서 한다.
public struct MarkdownText: View {
    private static let parser = MarkdownParser()

    private let document: MarkdownDocument

    public init(_ markdown: String) {
        document = Self.parser.parse(markdown)
    }

    public init(document: MarkdownDocument) {
        self.document = document
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DropTheme.Spacing.comfortable * 0.75) {
            ForEach(Array(document.blocks.enumerated()), id: \.offset) { _, block in
                MarkdownBlockView(block: block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 블록 하나. 인용이 자기 안에 블록을 다시 품기 때문에 재귀한다 —
/// `some View`는 스스로를 참조하지 못하므로 그 자리에서만 타입을 지운다.
struct MarkdownBlockView: View {
    let block: MarkdownBlock

    var body: some View {
        switch block {
        case let .heading(level, content):
            Text(MarkdownAttributedText.make(content))
                .font(Self.headingFont(level))
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)

        case let .paragraph(content):
            Text(MarkdownAttributedText.make(content))
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)

        case let .list(items):
            VStack(alignment: .leading, spacing: DropTheme.Spacing.tight) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    MarkdownListItemView(item: item)
                }
            }

        case let .codeBlock(_, code):
            // 코드는 접히면 안 된다 — 줄이 길면 세로가 아니라 가로로 넘긴다.
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(DropTheme.Spacing.base)
            }
            .background(DropTokens.Colors.bgTertiary, in: RoundedRectangle(cornerRadius: DropTheme.Radius.row))

        case let .quote(inner):
            HStack(alignment: .top, spacing: DropTheme.Spacing.base) {
                Capsule()
                    .fill(DropTokens.Colors.borderColor)
                    .frame(width: DropTheme.Hierarchy.railWidth)
                AnyView(
                    VStack(alignment: .leading, spacing: DropTheme.Spacing.base) {
                        ForEach(Array(inner.enumerated()), id: \.offset) { _, child in
                            MarkdownBlockView(block: child)
                        }
                    }
                )
            }
            .foregroundStyle(DropTokens.Colors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)

        case .thematicBreak:
            Divider()
        }
    }

    private static func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: .title2
        case 2: .title3
        case 3: .headline
        default: .subheadline
        }
    }
}

/// 목록 한 항목. 표식과 글자를 첫 줄 기준선에 맞춰 세운다 —
/// 가운데 정렬로 두면 두 줄짜리 항목에서 표식이 글 한가운데로 내려간다.
struct MarkdownListItemView: View {
    let item: MarkdownListItem

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DropTheme.Spacing.base) {
            marker
            Text(MarkdownAttributedText.make(item.content))
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, DropTheme.Hierarchy.indent * CGFloat(item.indent))
    }

    @ViewBuilder
    private var marker: some View {
        if let checked = item.checked {
            Image(systemName: checked ? "checkmark.square.fill" : "square")
                .font(.footnote)
                .foregroundStyle(checked ? DropTokens.Colors.accent : DropTokens.Colors.textTertiary)
                .accessibilityLabel(checked ? "완료" : "미완료")
        } else if let ordinal = item.ordinal {
            Text("\(ordinal).")
                .font(.body.monospacedDigit())
                .foregroundStyle(DropTokens.Colors.textSecondary)
        } else {
            Text("•")
                .font(.body)
                .foregroundStyle(DropTokens.Colors.textSecondary)
        }
    }
}

/// 인라인 요소를 `AttributedString`으로 옮긴다.
///
/// 굵게·기울임·코드는 `inlinePresentationIntent`로 얹는다 — 폰트를 직접 박으면
/// 제목 안의 굵게가 본문 크기로 떨어지고, 굵고 기울인 글자가 둘 중 하나를 잃는다.
///
/// 한글에는 이탤릭 자형이 없어 `*기울임*`이 화면에서 곧게 선다. 문법이 안 먹은 것이
/// 아니라 글꼴이 없는 것이고, 라틴 글자에서는 기운다.
enum MarkdownAttributedText {
    static func make(_ inlines: [MarkdownInline]) -> AttributedString {
        inlines.reduce(into: AttributedString()) { result, inline in
            result.append(make(inline))
        }
    }

    private static func make(_ inline: MarkdownInline) -> AttributedString {
        switch inline {
        case let .text(value):
            return AttributedString(value)

        case let .strong(content):
            return adding(.stronglyEmphasized, to: make(content))

        case let .emphasis(content):
            return adding(.emphasized, to: make(content))

        case let .code(value):
            var string = AttributedString(value)
            string.inlinePresentationIntent = .code
            string.foregroundColor = DropTokens.Colors.accent
            return string

        case let .link(content, destination):
            // 강조를 품은 링크 글자도 그대로 산다 — `AttributedString`이라
            // 주소와 서식이 한 조각에 함께 얹힌다.
            var string = make(content)
            // 주소가 URL로 서지 않으면 링크로 만들지 않는다 — 눌러도 아무 일이
            // 없는 파란 글자는 고장으로 읽힌다.
            if let url = URL(string: destination) {
                string.link = url
            }
            return string
        }
    }

    private static func adding(
        _ intent: InlinePresentationIntent,
        to string: AttributedString
    ) -> AttributedString {
        var result = string
        for range in result.runs.map(\.range) {
            let existing = result[range].inlinePresentationIntent ?? []
            result[range].inlinePresentationIntent = existing.union(intent)
        }
        return result
    }
}
