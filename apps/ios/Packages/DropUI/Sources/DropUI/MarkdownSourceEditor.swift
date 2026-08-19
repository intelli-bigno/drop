import SwiftUI
import UIKit

/// 마크다운 원문을 그대로 치는 편집기.
///
/// SwiftUI `TextEditor`가 아니라 `UITextView`를 감싼 이유는 하나 — **커서 위치**다.
/// 툴바가 "고른 글자를 굵게"를 하려면 선택 범위를 알아야 하는데, `TextEditor`의
/// `selection` 바인딩은 iOS 18부터이고 이 앱의 하한은 iOS 17이다 (BRU-37).
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
        view.backgroundColor = .clear
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
