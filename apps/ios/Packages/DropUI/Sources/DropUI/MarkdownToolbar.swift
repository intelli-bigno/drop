import DropCore
import SwiftUI

/// 작성 시트의 마크다운 입력 보조 (BRU-37).
///
/// 모바일 키보드에는 `#`도 `*`도 한 단계 들어가 있다 — 그 기호를 손으로 치게 두면
/// 마크다운은 "쓸 수는 있지만 아무도 안 쓰는 기능"이 된다.
public struct MarkdownToolbar: View {
    /// 툴바에 세울 명령과 그 얼굴. 순서가 곧 화면 순서다.
    private static let items: [(command: MarkdownEditingCommand, icon: String, label: String)] = [
        (.heading, "textformat.size", "제목"),
        (.bold, "bold", "굵게"),
        (.italic, "italic", "기울임"),
        (.bulletList, "list.bullet", "목록"),
        (.checkbox, "checklist", "체크박스"),
        (.code, "chevron.left.forwardslash.chevron.right", "코드"),
        (.quote, "text.quote", "인용"),
        (.link, "link", "링크"),
    ]

    private let onCommand: (MarkdownEditingCommand) -> Void

    public init(onCommand: @escaping (MarkdownEditingCommand) -> Void) {
        self.onCommand = onCommand
    }

    public var body: some View {
        // 좁은 화면에서 버튼이 줄어들거나 잘리는 대신 옆으로 넘어가게 둔다.
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DropTheme.Spacing.tight) {
                ForEach(Self.items, id: \.label) { item in
                    Button {
                        onCommand(item.command)
                    } label: {
                        Image(systemName: item.icon)
                            .font(.subheadline)
                            .frame(width: 40, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(DropTokens.Colors.textPrimary)
                    .accessibilityLabel(item.label)
                }
            }
            .padding(.horizontal, DropTheme.Spacing.base)
        }
        .frame(height: 44)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }
}
