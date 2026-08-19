import Foundation
import Testing

@testable import DropCore

/// 목록 한 줄 요약은 **스크롤할 때마다 다시 만들어지면 안 된다** (BRU-37).
///
/// SwiftUI의 행 `body`는 스크롤 한 번에도 여러 번 평가된다. 요약을 계산
/// 프로퍼티로 두면 그때마다 파서를 새로 만들어 최대 300자를 다시 파싱한다 —
/// 목록 스크롤이 곧 메인 스레드 파싱이 된다.
@Suite("한 줄 요약 캐시")
@MainActor
struct MarkdownSummaryCacheTests {
    @Test("같은 본문을 여러 번 물어봐도 한 번만 파싱한다")
    func parsesOncePerContent() {
        MarkdownSummaryCache.reset()
        let content = "## 제목\n\n본문 **굵게**"

        let first = MarkdownSummaryCache.summary(for: content)
        let second = MarkdownSummaryCache.summary(for: content)
        let third = MarkdownSummaryCache.summary(for: content)

        #expect(first == second)
        #expect(second == third)
        #expect(MarkdownSummaryCache.parseCount == 1)
    }

    @Test("본문이 바뀌면 다시 만든다")
    func reparsesWhenContentChanges() {
        MarkdownSummaryCache.reset()

        _ = MarkdownSummaryCache.summary(for: "첫 노트")
        _ = MarkdownSummaryCache.summary(for: "둘째 노트")

        #expect(MarkdownSummaryCache.parseCount == 2)
    }

    /// 앞부분만 읽는다 — 어차피 한 줄만 보이는데 긴 노트를 통째로 파싱하면
    /// 스크롤할 때마다 그 값을 치른다. 상한 뒤가 달라도 같은 요약이므로
    /// 캐시도 한 칸만 쓴다.
    @Test("상한 뒤가 다른 두 노트는 같은 캐시 칸을 쓴다")
    func onlyReadsThePrefix() {
        MarkdownSummaryCache.reset()
        let head = String(repeating: "가", count: MarkdownSummaryCache.previewCharacterLimit)

        _ = MarkdownSummaryCache.summary(for: head + "꼬리 하나")
        _ = MarkdownSummaryCache.summary(for: head + "완전히 다른 꼬리")

        #expect(MarkdownSummaryCache.parseCount == 1)
    }

    /// 노트가 무한히 쌓여도 캐시가 메모리를 무한히 먹지는 않는다.
    @Test("칸이 넘치면 오래된 것부터 버린다")
    func evictsOldestBeyondLimit() {
        MarkdownSummaryCache.reset()

        for index in 0 ... MarkdownSummaryCache.limit {
            _ = MarkdownSummaryCache.summary(for: "노트 \(index)")
        }
        #expect(MarkdownSummaryCache.count == MarkdownSummaryCache.limit)

        // 맨 처음 것은 밀려났으므로 다시 물으면 새로 파싱한다.
        let before = MarkdownSummaryCache.parseCount
        _ = MarkdownSummaryCache.summary(for: "노트 0")
        #expect(MarkdownSummaryCache.parseCount == before + 1)
    }
}
