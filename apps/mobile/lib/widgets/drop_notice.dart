/// 화면 안에 잠깐 서는 알림 줄 — 오류 배너 자리 (BRU-207).
///
/// 머티리얼 `MaterialBanner`는 화면 폭을 가득 채운 띠라 콘텐츠 종이를 위아래로
/// 가른다. 대신 거터 안에 앉는 눌러 넣은 면으로 그린다 — 목록과 같은 정렬선 위에
/// 서서 "지금 이 목록에 문제가 있다"로 읽힌다.
library;

import 'package:flutter/material.dart';

import '../theme/drop_theme.dart';

class DropNotice extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const DropNotice({super.key, required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final colors = DropColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DropLayout.gutter,
        DropTokenSpace.x2,
        DropLayout.gutter,
        DropTokenSpace.x2,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          DropTokenSpace.x4,
          DropTokenSpace.x3,
          DropTokenSpace.x2,
          DropTokenSpace.x3,
        ),
        decoration: BoxDecoration(
          color: colors.surfaceField,
          borderRadius: BorderRadius.circular(DropRadius.card),
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              size: DropIconSize.control,
              color: colors.danger,
            ),
            const SizedBox(width: DropTokenSpace.x3),
            Expanded(
              child: Text(
                message,
                style: DropText.body.copyWith(color: colors.textPrimary),
              ),
            ),
            TextButton(onPressed: onDismiss, child: const Text('확인')),
          ],
        ),
      ),
    );
  }
}
