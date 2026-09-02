/// 날짜 묶음의 머리글 — "오늘", "어제", "8월 27일".
///
/// 묶음(`NoteGroup`) 위에 서는 이름표다. 행 제목보다 굵고, 옆에 묶음의 개수를
/// 흐리게 붙인다 — "오늘 6"은 스크롤하지 않고도 묶음의 크기를 알려 준다.
/// 묶음 사이의 구분은 여백과 묶음 면이 하고, 머리글은 이름만 댄다.
library;

import 'package:flutter/material.dart';

import '../theme/drop_theme.dart';

class NoteSectionHeader extends StatelessWidget {
  final String title;

  /// 묶음 안의 행 수. null이면 개수를 그리지 않는다.
  final int? count;

  /// 첫 묶음은 필터 줄 바로 아래라 위 여백을 줄인다.
  final bool isFirst;

  const NoteSectionHeader({
    super.key,
    required this.title,
    this.count,
    this.isFirst = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = DropColors.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        DropLayout.gutter + DropTokenSpace.x1,
        isFirst ? DropTokenSpace.x3 : DropLayout.sectionGap,
        DropLayout.gutter,
        DropTokenSpace.x2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            title,
            style: DropText.cardTitle.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: DropTokenSpace.x2),
            Text(
              '$count',
              style: DropText.body.copyWith(
                color: colors.textTertiary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
