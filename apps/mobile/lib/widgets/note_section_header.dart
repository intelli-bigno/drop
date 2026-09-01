/// 날짜 묶음의 머리글 — "오늘", "어제", "8월 27일" (BRU-193에서 HomeScreen 밖으로 꺼냄).
///
/// 목록의 리듬을 만드는 물건인데 `_feed` 안에 인라인으로 박혀 있어서
/// 쇼케이스가 노트 행만 보여 주고 **묶음의 리듬**은 못 보여 줬다.
library;

import 'package:flutter/material.dart';

import '../theme/drop_theme.dart';

class NoteSectionHeader extends StatelessWidget {
  final String title;

  const NoteSectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final colors = DropColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DropTokenSpace.x4,
        DropTokenSpace.x3,
        DropTokenSpace.x4,
        DropTokenSpace.x1,
      ),
      child: Text(
        title,
        style: DropText.meta.copyWith(
          color: colors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
