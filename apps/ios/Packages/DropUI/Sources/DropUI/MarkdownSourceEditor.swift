import SwiftUI
import UIKit

/// 마크다운 원문을 그대로 치는 편집기.
///
/// SwiftUI `TextEditor`가 아니라 `UITextView`를 감싼 이유 — 하한이 iOS 26이 된
/// 지금(BRU-75) **커서 위치는 더 이상 이유가 아니다**. `TextEditor(text:selection:)`는
/// iOS 18부터 있다. 남은 이유는 자동 치환이다:
///
/// - **똑똑한 따옴표·대시를 끌 수 있는 것은 UIKit뿐이다.** SwiftUI에는
///   `smartQuotesType`·`smartDashesType`에 해당하는 API가 없다. 마크다운은 기호가
///   문법이라, `"`가 `“`로 바뀌는 순간 코드 블록도 링크도 깨진다.
/// - 툴바의 편집 명령(`MarkdownEditor`)이 `NSRange`로 도는데, SwiftUI의
///   `TextSelection`은 `String.Index` 범위(그것도 다중 선택 가능)라 매번 변환이 든다.
///
/// 앞의 이유가 없어지면 이 래퍼도 없어져야 한다 (BRU-37).
public struct MarkdownSourceEditor: UIViewRepresentable {
    @Binding private var text: String
    @Binding private var selection: NSRange
    private let focusesOnAppear: Bool

    public init(text: Binding<String>, selection: Binding<NSRange>, focusesOnAppear: Bool = false) {
        _text = text
        _selection = selection
        self.focusesOnAppear = focusesOnAppear
    }

    public func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        view.font = .preferredFont(forTextStyle: .body)
        view.adjustsFontForContentSizeCategory = true
        // 배경은 시트가 깐 종이(`DropTheme.Surface.page`)를 그대로 비춘다.
        // 글자·커서는 팔레트에서 가져온다 — UIKit의 기본 label 색은 웜 페이퍼 밖이다.
        view.backgroundColor = .clear
        view.textColor = UIColor(DropTokens.Colors.textPrimary)
        view.tintColor = UIColor(DropTokens.Colors.accent)
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        // 마크다운은 기호가 문법이다. 자동 대문자·자동 수정이 켜져 있으면
        // 사용자가 친 기호가 소리 없이 바뀐다.
        view.autocapitalizationType = .none
        view.autocorrectionType = .no
        view.smartDashesType = .no
        view.smartQuotesType = .no
        view.smartInsertDeleteType = .no
        view.text = text
        view.selectedRange = selection

        if focusesOnAppear {
            // 시트가 뜨자마자 키보드가 올라와야 "던져넣기"가 끊기지 않는다.
            DispatchQueue.main.async { view.becomeFirstResponder() }
        }
        return view
    }

    public func updateUIView(_ view: UITextView, context: Context) {
        // 사용자가 지금 치고 있는 글자를 되감지 않는다.
        guard !context.coordinator.isEditingFromUIKit else { return }

        if view.text != text { view.text = text }
        if view.selectedRange != selection, selection.upperBound <= (view.text as NSString).length {
            view.selectedRange = selection
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, selection: $selection)
    }

    public final class Coordinator: NSObject, UITextViewDelegate {
        @Binding private var text: String
        @Binding private var selection: NSRange
        /// UIKit이 알려 준 변화를 SwiftUI가 되돌려 쓰는 왕복을 끊는다.
        fileprivate var isEditingFromUIKit = false

        init(text: Binding<String>, selection: Binding<NSRange>) {
            _text = text
            _selection = selection
        }

        public func textViewDidChange(_ textView: UITextView) {
            isEditingFromUIKit = true
            text = textView.text
            selection = textView.selectedRange
            isEditingFromUIKit = false
        }

        public func textViewDidChangeSelection(_ textView: UITextView) {
            guard selection != textView.selectedRange else { return }
            isEditingFromUIKit = true
            selection = textView.selectedRange
            isEditingFromUIKit = false
        }
    }
}
