/// drop_core `MarkdownParser`의 결과를 그대로 위젯으로 옮기는 렌더러.
///
/// 외부 마크다운 패키지를 쓰지 않는 이유: 파싱 규칙의 정본은 drop_core다
/// (`#태그`는 제목이 아니고, 체크박스·중첩 목록·닫히지 않은 펜스의 처리까지
/// iOS DropCore와 1:1). 패키지를 얹으면 파서가 두 개가 되어 목록 요약과
/// 뷰어 본문이 서로 다른 해석을 하게 된다.
///
/// **본문을 바꾸는 길은 체크박스 하나뿐이다** (BRU-207). `onToggleCheckbox`를
/// 주면 체크박스가 눌리고, 주지 않으면 전과 같이 그리기만 한다(컴포저 미리보기).
/// 그 외의 모든 편집은 여전히 편집기로만 간다 — 열람만 했는데 본문이 달라지던
/// 사고(BRU-66)를 막는 계약은 그대로다.
///
/// 시각 규칙 (BRU-207):
///  - **인용은 면도 선도 없다.** 색만 한 단 낮춘다 — 인용을 회색 카드로 만들면
///    코드 블록과 생김새가 똑같아져 둘을 구별할 수 없다.
///  - **강조는 형광펜.** 기울임은 한글에서 가짜 기울기라 강조로 읽히지 않고,
///    액센트 색만 쓰면 링크와 구별되지 않는다.
///  - **코드는 접어서 보여 준다.** 옆으로 숨기면 잘린 문장으로 보인다.
library;

import 'package:drop_core/drop_core.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/drop_theme.dart';
import 'drop_feedback.dart';

class MarkdownView extends StatefulWidget {
  final String source;

  /// 체크박스를 눌렀을 때 바뀐 **본문 전체**를 받는 손. null이면 읽기 전용.
  final ValueChanged<String>? onToggleCheckbox;

  const MarkdownView({super.key, required this.source, this.onToggleCheckbox});

  @override
  State<MarkdownView> createState() => _MarkdownViewState();
}

/// 상태를 두는 이유는 **링크 하나뿐**이다 — 탭 인식기는 만든 쪽이 버려야 해서
/// (안 버리면 다시 그릴 때마다 샌다) 이 위젯이 수명을 쥔다.
class _MarkdownViewState extends State<MarkdownView> {
  static const _parser = MarkdownParser();

  final _recognizers = <TapGestureRecognizer>[];

  String get source => widget.source;

  ValueChanged<String>? get onToggleCheckbox => widget.onToggleCheckbox;

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  /// 링크를 연다. 열 수 없는 주소(스킴 없음·앱 없음)면 조용히 넘기지 않고 말한다.
  Future<void> _open(String destination) async {
    final uri = Uri.tryParse(destination);
    if (uri == null || !uri.hasScheme) {
      if (mounted) showDropToast(context, '열 수 없는 주소예요');
      return;
    }
    DropHaptics.select();
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) showDropToast(context, '이 링크를 열 앱이 없어요');
  }

  @override
  Widget build(BuildContext context) {
    // 이번 그리기에서 쓸 인식기를 새로 만들기 전에 지난 것을 버린다.
    _disposeRecognizers();
    final document = _parser.parse(source);
    final colors = DropColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, block) in document.blocks.indexed) ...[
          if (index > 0) SizedBox(height: _gapBefore(block)),
          _blockWidget(block, colors, isQuoted: false),
        ],
      ],
    );
  }

  /// 블록 사이 숨. 제목 앞은 넓게 벌려 "여기서 이야기가 바뀐다"를 여백이 말한다.
  double _gapBefore(MarkdownBlock block) => switch (block) {
    MarkdownHeading(:final level) =>
      level <= 2 ? DropTokenSpace.x5 : DropTokenSpace.x4,
    MarkdownList() => DropTokenSpace.x3,
    _ => DropTokenSpace.x3,
  };

  Widget _blockWidget(
    MarkdownBlock block,
    DropTokenColors colors, {
    required bool isQuoted,
  }) {
    final bodyColor = isQuoted ? colors.textSecondary : colors.textPrimary;
    switch (block) {
      case MarkdownHeading(:final level, :final content):
        return Text.rich(
          _spans(content, colors, bodyColor),
          style: _headingStyle(level).copyWith(color: colors.textPrimary),
        );

      case MarkdownParagraph(:final content):
        return Text.rich(
          _spans(content, colors, bodyColor),
          style: DropText.reading.copyWith(color: bodyColor),
        );

      case MarkdownList(:final items):
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final item in items) _listItemWidget(item, colors, bodyColor),
          ],
        );

      case MarkdownCodeBlock(:final code):
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: DropTokenSpace.x4,
            vertical: DropTokenSpace.x3,
          ),
          decoration: BoxDecoration(
            color: colors.surfaceField,
            borderRadius: BorderRadius.circular(DropRadius.card),
          ),
          // 접어서 보여 준다 — 옆으로 숨기면 화면에는 잘린 문장만 남는다.
          child: Text(
            code,
            style: DropText.body.copyWith(
              fontFamily: 'monospace',
              color: colors.textPrimary,
              height: 1.5,
            ),
          ),
        );

      case MarkdownQuote(:final blocks):
        // 면도 선도 없다. 색이 한 단 낮아진 것만으로 "다른 목소리"가 읽힌다.
        return Padding(
          padding: const EdgeInsets.only(left: DropTokenSpace.x3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, inner) in blocks.indexed) ...[
                if (index > 0) const SizedBox(height: DropTokenSpace.x2),
                _blockWidget(inner, colors, isQuoted: true),
              ],
            ],
          ),
        );

      case MarkdownThematicBreak():
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: DropTokenSpace.x2),
          child: Divider(),
        );
    }
  }

  Widget _listItemWidget(
    MarkdownListItem item,
    DropTokenColors colors,
    Color bodyColor,
  ) {
    final isCheckbox = item.checked != null;
    final isDone = item.checked == true;
    return Padding(
      padding: EdgeInsets.only(
        left: DropLayout.indent * item.indent,
        // 체크박스 줄은 손가락이 닿아야 해서 위아래로 조금 더 벌린다.
        bottom: isCheckbox ? 0 : DropTokenSpace.x1,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _marker(item, colors),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: isCheckbox ? DropTokenSpace.x2 + 2 : 0,
              ),
              child: Text.rich(
                _spans(item.content, colors, bodyColor),
                style: DropText.reading.copyWith(
                  // 끝낸 항목은 지우지 않고 흐린다 — 목록 행과 같은 규칙(BRU-184).
                  color: isDone ? colors.textMuted : bodyColor,
                  decoration: isDone ? TextDecoration.lineThrough : null,
                  decorationColor: colors.textMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 체크박스는 `onToggleCheckbox`가 있을 때만 눌린다. 닿는 면은 세로 44 —
  /// 아이콘(20)을 정확히 맞출 필요가 없어야 한다.
  Widget _marker(MarkdownListItem item, DropTokenColors colors) {
    final checked = item.checked;
    if (checked == null) {
      final ordinal = item.ordinal;
      return SizedBox(
        width: DropTokenSpace.x5,
        child: Text(
          ordinal != null ? '$ordinal.' : '•',
          textAlign: TextAlign.left,
          style: DropText.reading.copyWith(
            color: colors.textTertiary,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final icon = Icon(
      checked ? Icons.check_box : Icons.check_box_outline_blank,
      size: DropIconSize.control,
      color: checked ? colors.accent : colors.textMuted,
    );
    final toggle = onToggleCheckbox;
    if (toggle == null) {
      return SizedBox(
        width: DropTokenSpace.x5 + DropTokenSpace.x1,
        height: 44,
        child: Center(child: icon),
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        DropHaptics.select();
        toggle(MarkdownChecklist.toggleLine(source, item.sourceLine));
      },
      child: SizedBox(
        width: DropTokenSpace.x5 + DropTokenSpace.x1,
        height: 44,
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            switchInCurve: Curves.easeOutBack,
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: KeyedSubtree(key: ValueKey(checked), child: icon),
          ),
        ),
      ),
    );
  }

  TextStyle _headingStyle(int level) => switch (level) {
    1 => DropText.sectionTitle,
    2 => DropText.cardTitle.copyWith(fontWeight: FontWeight.w700),
    _ => DropText.cardTitle.copyWith(fontWeight: FontWeight.w600),
  };

  TextSpan _spans(
    List<MarkdownInline> content,
    DropTokenColors colors,
    Color bodyColor,
  ) => TextSpan(
    children: [for (final inline in content) _span(inline, colors, bodyColor)],
  );

  TextSpan _span(
    MarkdownInline inline,
    DropTokenColors colors,
    Color bodyColor,
  ) {
    switch (inline) {
      case MarkdownText(:final value):
        return TextSpan(text: value);

      case MarkdownStrong(:final content):
        return TextSpan(
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
          children: [
            for (final inner in content) _span(inner, colors, bodyColor),
          ],
        );

      case MarkdownEmphasis(:final content):
        // 형광펜. 기울임은 한글에서 가짜 기울기라 강조로 안 읽히고, 액센트 색만
        // 쓰면 링크와 같아진다 — 글자는 본문색 그대로 두고 뒤에 색을 깐다.
        return TextSpan(
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
            background: Paint()
              ..color = colors.accentSubtle
              ..strokeJoin = StrokeJoin.round,
          ),
          children: [
            for (final inner in content) _span(inner, colors, bodyColor),
          ],
        );

      case MarkdownCode(:final value):
        return TextSpan(
          text: value,
          style: TextStyle(
            fontFamily: 'monospace',
            color: colors.textPrimary,
            background: Paint()..color = colors.surfaceField,
          ),
        );

      case MarkdownLink(:final content, :final destination):
        final recognizer = TapGestureRecognizer()
          ..onTap = () => _open(destination);
        _recognizers.add(recognizer);
        return TextSpan(
          recognizer: recognizer,
          style: TextStyle(
            color: colors.accent,
            fontWeight: FontWeight.w500,
            decoration: TextDecoration.underline,
            decorationColor: colors.accent,
          ),
          children: [
            for (final inner in content) _span(inner, colors, bodyColor),
          ],
        );
    }
  }
}
