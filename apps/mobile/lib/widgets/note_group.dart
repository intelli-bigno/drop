/// 노트 행들을 하나로 묶는 둥근 면 (BRU-207).
///
/// 섹션("오늘")마다 하나씩 — 섹션 사이는 바탕이 보이는 여백이 가르고, 섹션 안의
/// 노트 하나하나는 얇은 선이 가른다. 행 자체는 카드가 아니다(테두리·그림자 없음);
/// 묶음이 한 장의 종이고, 그 위에 줄이 그어져 있을 뿐이다.
library;

import 'package:flutter/material.dart';

import '../theme/drop_theme.dart';

class NoteGroup extends StatelessWidget {
  final List<Widget> children;

  /// 고정 묶음 — 왼쪽 위 모서리에 핀을 비스듬히 꽂는다. 행 안의 아이콘 대신
  /// 묶음 자체가 "꽂혀 있다"를 말한다 (BRU-207 피드백: 살짝 어긋난 오버레이).
  final bool isPinned;

  const NoteGroup({super.key, required this.children, this.isPinned = false});

  /// 묶음 안쪽 좌우 여백. 화면 거터(20)보다 한 단 작아, 묶음 테두리에서 글자까지가
  /// 화면 가장자리에서 묶음까지의 거리보다 짧다 — 그래야 글자가 "안에 들어 있다"로 읽힌다.
  static const double inset = DropTokenSpace.x4; // 16

  @override
  Widget build(BuildContext context) {
    final colors = DropColors.of(context);
    final group = Padding(
      padding: const EdgeInsets.symmetric(horizontal: DropLayout.gutter),
      child: Material(
        color: colors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DropRadius.overlay),
          // 다크에서는 카드 면과 바탕의 명도 차가 작아 선 하나가 경계를 받쳐 준다.
          side: BorderSide(color: colors.borderSubtle),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (index, child) in children.indexed) ...[
              if (index > 0)
                Divider(
                  indent: inset,
                  endIndent: inset,
                  color: colors.borderColor,
                ),
              child,
            ],
          ],
        ),
      ),
    );
    if (!isPinned) return group;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        group,
        Positioned(
          left: DropLayout.gutter - DropTokenSpace.x2,
          top: -DropTokenSpace.x2,
          child: IgnorePointer(
            child: Transform.rotate(
              angle: -0.55, // 약 -31°. 반듯하면 로고처럼 보이고, 기울면 꽂은 것처럼 보인다.
              child: Icon(
                Icons.push_pin,
                size: DropIconSize.action + 2,
                color: colors.accent,
                shadows: [
                  Shadow(
                    color: DropTokenColors.dark.bgPrimary.withValues(
                      alpha: 0.35,
                    ),
                    offset: const Offset(1, 2),
                    blurRadius: 3,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
