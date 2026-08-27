import 'markdown_parser.dart';

/// 목록 한 줄 행에 태울 평문 요약을 만들고 **기억한다** (BRU-37).
/// DropCore `MarkdownSummaryCache.swift` 대응.
///
/// 원문을 그대로 태우면 `## 제목`이 `##`째로 보인다 — 한 줄만 보이는 자리에서는
/// 기호가 읽을 수 있는 정보의 절반을 먹는다. 그래서 문법을 걷어낸 평문을 쓴다.
///
/// 기억해 두는 이유는 성능이다. 목록 행 위젯은 스크롤 한 번에도 여러 번
/// 다시 빌드되는데, 요약을 매번 계산하면 그때마다 최대 300자를 다시 파싱한다 —
/// **목록 스크롤이 곧 메인 스레드 파싱이 된다.** 파서는 하나만 두고,
/// 같은 본문에 대한 답은 다시 만들지 않는다.
class MarkdownSummaryCache {
  MarkdownSummaryCache._();

  /// 요약을 만들 때 읽는 원문 길이의 상한.
  /// 어차피 한 줄만 보이는데 긴 노트를 통째로 파싱하면 스크롤할 때마다 그 값을 치른다.
  static const previewCharacterLimit = 300;

  /// 기억해 둘 요약의 최대 개수. 노트가 무한히 쌓여도 캐시는 여기서 멈춘다.
  static const limit = 512;

  static const _parser = MarkdownParser();
  static final _entries = <String, String>{};

  /// 넣은 순서. 넘치면 가장 오래된 것부터 버린다.
  static final _order = <String>[];

  /// 테스트가 "정말 한 번만 파싱했는지" 볼 수 있게 세어 둔다.
  static int _parseCount = 0;
  static int get parseCount => _parseCount;

  static String summaryFor(String content) {
    final source = content.length <= previewCharacterLimit
        ? content
        : content.substring(0, previewCharacterLimit);
    final remembered = _entries[source];
    if (remembered != null) return remembered;

    final summary = _parser.parse(source).singleLineSummary;
    _parseCount += 1;
    _entries[source] = summary;
    _order.add(source);
    if (_order.length > limit) {
      _entries.remove(_order.removeAt(0));
    }
    return summary;
  }

  static int get count => _entries.length;

  static void reset() {
    _entries.clear();
    _order.clear();
    _parseCount = 0;
  }
}
