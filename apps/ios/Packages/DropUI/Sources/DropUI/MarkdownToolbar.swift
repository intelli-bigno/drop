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
        // 툴바는 **기능 레이어**다 — 콘텐츠(종이) 위에 떠서 손이 닿는 자리이므로
        // 유리가 맞다. 시스템 재질(.bar)은 웜 페이퍼 팔레트 밖이라 이 줄만
        // 시스템 외양으로 되돌아간다 (BRU-75).
        .glassEffect(.regular, in: Rectangle())
        .overlay(alignment: .top) { Divider() }
    }
}
