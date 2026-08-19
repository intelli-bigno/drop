import Foundation

/// 목록 한 줄 행에 태울 평문 요약을 만들고 **기억한다** (BRU-37).
///
/// 원문을 그대로 태우면 `## 제목`이 `##`째로 보인다 — 한 줄만 보이는 자리에서는
/// 기호가 읽을 수 있는 정보의 절반을 먹는다. 그래서 문법을 걷어낸 평문을 쓴다.
///
/// 기억해 두는 이유는 성능이다. SwiftUI의 행 `body`는 스크롤 한 번에도 여러 번
/// 평가되는데, 요약을 계산 프로퍼티로 두면 그때마다 파서를 새로 만들어 최대 300자를
/// 다시 파싱한다 — **목록 스크롤이 곧 메인 스레드 파싱이 된다.** 파서는 하나만
/// 두고, 같은 본문에 대한 답은 다시 만들지 않는다.
///
/// 메인 액터에 묶어 둔 것은 잠금 없이 쓰기 위해서다. 부르는 곳이 SwiftUI의
/// `body` 하나뿐이라 그것으로 충분하다.
@MainActor
public enum MarkdownSummaryCache {
    /// 요약을 만들 때 읽는 원문 길이의 상한.
    /// 어차피 한 줄만 보이는데 긴 노트를 통째로 파싱하면 스크롤할 때마다 그 값을 치른다.
    public static let previewCharacterLimit = 300

    /// 기억해 둘 요약의 최대 개수. 노트가 무한히 쌓여도 캐시는 여기서 멈춘다.
    static let limit = 512

    private static let parser = MarkdownParser()
    private static var entries: [String: String] = [:]
    /// 넣은 순서. 넘치면 가장 오래된 것부터 버린다.
    private static var order: [String] = []

    /// 테스트가 "정말 한 번만 파싱했는지" 볼 수 있게 세어 둔다.
    private(set) static var parseCount = 0

    public static func summary(for content: String) -> String {
        let source = String(content.prefix(previewCharacterLimit))
        if let remembered = entries[source] { return remembered }

        let summary = parser.parse(source).singleLineSummary
        parseCount += 1
        entries[source] = summary
        order.append(source)
        if order.count > limit {
            entries.removeValue(forKey: order.removeFirst())
        }
        return summary
    }

    static var count: Int { entries.count }

    static func reset() {
        entries.removeAll()
        order.removeAll()
        parseCount = 0
    }
}
