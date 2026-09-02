/// 바닥에서 올라오는 행동 목록 — 머티리얼 팝업 메뉴 대신 쓰는 오버레이 (BRU-207).
///
/// 손가락이 닿는 곳(화면 아래)에 큰 행으로 서고, 지금 켜진 것은 체크로,
/// 되돌릴 수 없는 것은 danger 색으로 말한다. 고른 값을 **돌려주기만** 하고
/// 실행은 부른 쪽이 한다 — 시트가 닫히는 것과 화면이 바뀌는 것을 한 곳에서
/// 순서대로 다루기 위해서다.
library;

import 'package:flutter/material.dart';

import '../theme/drop_theme.dart';

class DropSheetAction<T> {
  final T value;
  final String label;
  final IconData icon;
  final bool isOn;
  final bool isDestructive;

  const DropSheetAction({
    required this.value,
    required this.label,
    required this.icon,
    this.isOn = false,
    this.isDestructive = false,
  });
}

Future<T?> showDropActionSheet<T>(
  BuildContext context, {
  String? title,
  required List<DropSheetAction<T>> actions,
}) => showModalBottomSheet<T>(
  context: context,
  useSafeArea: true,
  builder: (sheetContext) => _ActionSheet<T>(title: title, actions: actions),
);

class _ActionSheet<T> extends StatelessWidget {
  final String? title;
  final List<DropSheetAction<T>> actions;

  const _ActionSheet({required this.title, required this.actions});

  @override
  Widget build(BuildContext context) {
    final colors = DropColors.of(context);
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DropLayout.gutter,
                DropTokenSpace.x1,
                DropLayout.gutter,
                DropTokenSpace.x2,
              ),
              child: Text(
                title!,
                style: DropText.sectionTitle.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ),
          for (final action in actions) _ActionRow<T>(action: action),
          const SizedBox(height: DropTokenSpace.x3),
        ],
      ),
    );
  }
}

class _ActionRow<T> extends StatelessWidget {
  final DropSheetAction<T> action;

  const _ActionRow({required this.action});

  @override
  Widget build(BuildContext context) {
    final colors = DropColors.of(context);
    final color = action.isDestructive ? colors.danger : colors.textPrimary;
    return InkWell(
      onTap: () => Navigator.of(context).pop(action.value),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DropLayout.gutter,
          vertical: DropTokenSpace.x4,
        ),
        child: Row(
          children: [
            Icon(
              action.icon,
              size: DropIconSize.action,
              color: action.isDestructive
                  ? colors.danger
                  : colors.textSecondary,
            ),
            const SizedBox(width: DropTokenSpace.x4),
            Expanded(
              child: Text(
                action.label,
                style: DropText.cardTitle.copyWith(color: color),
              ),
            ),
            if (action.isOn)
              Icon(
                Icons.check,
                size: DropIconSize.control,
                color: colors.accent,
              ),
          ],
        ),
      ),
    );
  }
}

/// 시트 맨 위 줄 — 제목은 왼쪽, 닫기는 오른쪽. 컴포저·댓글이 같은 줄을 쓴다.
class DropSheetHeader extends StatelessWidget {
  final String title;

  /// 제목 옆에 작게 붙는 것 — 개수·부제.
  final String? subtitle;
  final VoidCallback? onClose;

  const DropSheetHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final colors = DropColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DropLayout.gutter,
        0,
        DropTokenSpace.x2,
        DropTokenSpace.x2,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                text: title,
                children: [
                  if (subtitle != null)
                    TextSpan(
                      text: '  $subtitle',
                      style: DropText.cardTitle.copyWith(
                        color: colors.textTertiary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                ],
              ),
              style: DropText.sectionTitle.copyWith(color: colors.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onClose != null)
            IconButton(
              tooltip: '닫기',
              icon: const Icon(Icons.close),
              onPressed: onClose,
            ),
        ],
      ),
    );
  }
}
