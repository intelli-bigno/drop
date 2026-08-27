/// drop_core `MarkdownParser`의 결과를 그대로 위젯으로 옮기는 렌더러.
///
/// 외부 마크다운 패키지를 쓰지 않는 이유: 파싱 규칙의 정본은 drop_core다
/// (`#태그`는 제목이 아니고, 체크박스·중첩 목록·닫히지 않은 펜스의 처리까지
/// iOS DropCore와 1:1). 패키지를 얹으면 파서가 두 개가 되어 목록 요약과
/// 뷰어 본문이 서로 다른 해석을 하게 된다.
///
/// **읽기 전용이다.** 체크박스도 그리기만 하고 토글하지 않는다 —
/// 뷰어에서 본문이 나가는 길은 편집기뿐이다 (BRU-77).
library;

import 'package:drop_core/drop_core.dart';
import 'package:flutter/material.dart';

class MarkdownView extends StatelessWidget {
  static const _parser = MarkdownParser();

  final String source;

  const MarkdownView({super.key, required this.source});

  @override
  Widget build(BuildContext context) {
    final document = _parser.parse(source);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, block) in document.blocks.indexed) ...[
          if (index > 0) const SizedBox(height: 12),
          _blockWidget(block, theme),
        ],
      ],
    );
  }

  Widget _blockWidget(MarkdownBlock block, ThemeData theme) {
    switch (block) {
      case MarkdownHeading(:final level, :final content):
        return Text.rich(
          _spans(content, theme),
          style: _headingStyle(level, theme),
        );
      case MarkdownParagraph(:final content):
        return Text.rich(_spans(content, theme), style: theme.textTheme.bodyMedium);
      case MarkdownList(:final items):
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (index, item) in items.indexed) ...[
              if (index > 0) const SizedBox(height: 4),
              _listItemWidget(item, theme),
            ],
          ],
        );
      case MarkdownCodeBlock(:final code):
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              code,
              style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
            ),
          ),
        );
      case MarkdownQuote(:final blocks):
        return Container(
          padding: const EdgeInsets.only(left: 12),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: theme.colorScheme.outlineVariant, width: 3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, inner) in blocks.indexed) ...[
                if (index > 0) const SizedBox(height: 8),
                _blockWidget(inner, theme),
              ],
            ],
          ),
        );
      case MarkdownThematicBreak():
        return const Divider();
    }
  }

  Widget _listItemWidget(MarkdownListItem item, ThemeData theme) {
    final style = theme.textTheme.bodyMedium;
    return Padding(
      padding: EdgeInsets.only(left: 16.0 * item.indent),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 24, child: _marker(item, theme)),
          Expanded(child: Text.rich(_spans(item.content, theme), style: style)),
        ],
      ),
    );
  }

  /// 체크박스는 상태를 그리기만 한다 — 뷰어는 아무것도 되돌려 쓰지 않는다.
  Widget _marker(MarkdownListItem item, ThemeData theme) {
    final checked = item.checked;
    if (checked != null) {
      return Icon(
        checked ? Icons.check_box : Icons.check_box_outline_blank,
        size: 18,
        color: checked
            ? theme.colorScheme.primary
            : theme.colorScheme.outline,
      );
    }
    final ordinal = item.ordinal;
    return Text(
      ordinal != null ? '$ordinal.' : '•',
      style: theme.textTheme.bodyMedium,
    );
  }

  TextStyle? _headingStyle(int level, ThemeData theme) => switch (level) {
        1 => theme.textTheme.headlineSmall,
        2 => theme.textTheme.titleLarge,
        3 => theme.textTheme.titleMedium,
        _ => theme.textTheme.titleSmall,
      };

  TextSpan _spans(List<MarkdownInline> content, ThemeData theme) =>
      TextSpan(children: [for (final inline in content) _span(inline, theme)]);

  TextSpan _span(MarkdownInline inline, ThemeData theme) {
    switch (inline) {
      case MarkdownText(:final value):
        return TextSpan(text: value);
      case MarkdownStrong(:final content):
        return TextSpan(
          style: const TextStyle(fontWeight: FontWeight.w700),
          children: [for (final inner in content) _span(inner, theme)],
        );
      case MarkdownEmphasis(:final content):
        return TextSpan(
          style: const TextStyle(fontStyle: FontStyle.italic),
          children: [for (final inner in content) _span(inner, theme)],
        );
      case MarkdownCode(:final value):
        return TextSpan(
          text: value,
          style: TextStyle(
            fontFamily: 'monospace',
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        );
      case MarkdownLink(:final content):
        // 링크는 표시만 한다 — 브라우저 열기는 url_launcher 의존이 필요해
        // 테마 트랙(BRU-159) 이후 별도 판단으로 미룬다.
        return TextSpan(
          style: TextStyle(
            color: theme.colorScheme.primary,
            decoration: TextDecoration.underline,
          ),
          children: [for (final inner in content) _span(inner, theme)],
        );
    }
  }
}
