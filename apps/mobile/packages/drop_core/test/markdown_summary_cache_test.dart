import 'package:drop_core/drop_core.dart';
import 'package:test/test.dart';

/// DropCore `MarkdownSummaryCacheTests.swift` 포팅.
/// 목록 한 줄 요약은 **스크롤할 때마다 다시 만들어지면 안 된다** (BRU-37).
void main() {
  group('한 줄 요약 캐시', () {
    test('같은 본문을 여러 번 물어봐도 한 번만 파싱한다', () {
      MarkdownSummaryCache.reset();
      const content = '## 제목\n\n본문 **굵게**';

      final first = MarkdownSummaryCache.summaryFor(content);
      final second = MarkdownSummaryCache.summaryFor(content);
      final third = MarkdownSummaryCache.summaryFor(content);

      expect(first, second);
      expect(second, third);
      expect(MarkdownSummaryCache.parseCount, 1);
    });

    test('본문이 바뀌면 다시 만든다', () {
      MarkdownSummaryCache.reset();

      MarkdownSummaryCache.summaryFor('첫 노트');
      MarkdownSummaryCache.summaryFor('둘째 노트');

      expect(MarkdownSummaryCache.parseCount, 2);
    });

    /// 앞부분만 읽는다 — 어차피 한 줄만 보이는데 긴 노트를 통째로 파싱하면
    /// 스크롤할 때마다 그 값을 치른다. 상한 뒤가 달라도 같은 요약이므로
    /// 캐시도 한 칸만 쓴다.
    test('상한 뒤가 다른 두 노트는 같은 캐시 칸을 쓴다', () {
      MarkdownSummaryCache.reset();
      final head = '가' * MarkdownSummaryCache.previewCharacterLimit;

      MarkdownSummaryCache.summaryFor('$head꼬리 하나');
      MarkdownSummaryCache.summaryFor('$head완전히 다른 꼬리');

      expect(MarkdownSummaryCache.parseCount, 1);
    });

    /// 노트가 무한히 쌓여도 캐시가 메모리를 무한히 먹지는 않는다.
    test('칸이 넘치면 오래된 것부터 버린다', () {
      MarkdownSummaryCache.reset();

      for (var index = 0; index <= MarkdownSummaryCache.limit; index += 1) {
        MarkdownSummaryCache.summaryFor('노트 $index');
      }
      expect(MarkdownSummaryCache.count, MarkdownSummaryCache.limit);

      // 맨 처음 것은 밀려났으므로 다시 물으면 새로 파싱한다.
      final before = MarkdownSummaryCache.parseCount;
      MarkdownSummaryCache.summaryFor('노트 0');
      expect(MarkdownSummaryCache.parseCount, before + 1);
    });
  });
}
