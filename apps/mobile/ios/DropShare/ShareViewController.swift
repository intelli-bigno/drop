import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// 공유 시트에서 DROP을 고르면 뜨는 확장. `apps/ios/DropShare` 이식본 —
/// DropCore·DropUI 의존만 `DropShell/`의 이식 조각으로 바꿨다.
///
/// 여기서 Supabase에 바로 쓰지 않는다. 확장은 메모리 한도(약 120MB)가 좁고
/// 로그인 세션이 없을 수도 있다. App Group 컨테이너에 **적어 두기만** 하고,
/// 앱이 켜질 때 그것을 비우며 노트를 만든다.
final class ShareViewController: UIViewController {
    private let statusLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpStatusLabel()

        Task {
            await handleSharedContent()
            finish()
        }
    }

    private func setUpStatusLabel() {
        // 공유 확장도 앱과 같은 웜 페이퍼를 쓴다 (BRU-75). 시스템 기본 배경을
        // 두면 공유 시트에서 여기만 다른 앱처럼 보인다.
        view.backgroundColor = UIColor(DropShellTokens.pageBackground)
        statusLabel.textColor = UIColor(DropShellTokens.textPrimary)
        statusLabel.text = "DROP에 담는 중…"
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    private func handleSharedContent() async {
        guard
            let inbox = SharedInbox(),
            let items = extensionContext?.inputItems as? [NSExtensionItem]
        else { return }

        var texts: [String] = []
        var fileNames: [String] = []
        try? inbox.prepareFilesDirectory()

        for item in items {
            for provider in item.attachments ?? [] {
                if let text = await provider.loadText() {
                    texts.append(text)
                } else if let (data, suggestedName) = await provider.loadFile() {
                    let name = "\(UUID().uuidString)-\(suggestedName)"
                    // 확장이 끝나면 임시 파일이 사라지므로 컨테이너로 복사해 둔다.
                    if (try? data.write(to: inbox.fileURL(named: name))) != nil {
                        fileNames.append(name)
                    }
                }
            }
        }

        guard !texts.isEmpty || !fileNames.isEmpty else { return }
        try? inbox.enqueue(SharedItem(text: texts.joined(separator: "\n"), fileNames: fileNames))
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}

/// 공유 항목에서 꺼낸 파일 한 건.
private struct SharedFile: Sendable {
    let data: Data
    let name: String
}

@MainActor
private extension NSItemProvider {
    func loadText() async -> String? {
        if hasItemConformingToTypeIdentifier(UTType.url.identifier),
           let text = await loadSendable(UTType.url.identifier, transform: { ($0 as? URL)?.absoluteString })
        {
            return text
        }
        if hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            return await loadSendable(UTType.plainText.identifier, transform: { $0 as? String })
        }
        return nil
    }

    /// 이미지·동영상·파일을 데이터로 읽는다. 확장의 메모리 한도(약 120MB)를 넘기지 않도록
    /// 큰 파일은 건너뛴다 — 넘기면 확장이 통째로 죽어 아무것도 저장되지 않는다.
    func loadFile() async -> (Data, String)? {
        for type in [UTType.image, .movie, .fileURL] where hasItemConformingToTypeIdentifier(type.identifier) {
            let file = await loadSendable(type.identifier) { item -> SharedFile? in
                if let url = item as? URL,
                   let data = try? Data(contentsOf: url, options: .mappedIfSafe),
                   data.count <= 50 * 1024 * 1024
                {
                    return SharedFile(data: data, name: url.lastPathComponent)
                }
                if let image = item as? UIImage, let data = image.jpegData(compressionQuality: 0.9) {
                    return SharedFile(data: data, name: "shared.jpg")
                }
                return nil
            }
            if let file { return (file.data, file.name) }
        }
        return nil
    }

    /// `NSItemProvider`가 주는 값은 Sendable이 아니다.
    /// 완료 블록 안에서 바로 Sendable한 값으로 바꿔 내보낸다.
    func loadSendable<T: Sendable>(
        _ identifier: String,
        transform: @escaping @Sendable (NSSecureCoding?) -> T?
    ) async -> T? {
        await withCheckedContinuation { continuation in
            loadItem(forTypeIdentifier: identifier, options: nil) { item, _ in
                continuation.resume(returning: transform(item))
            }
        }
    }
}
