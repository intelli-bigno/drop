/// 손끝의 되먹임 — 햅틱·토스트·확인 시트 (BRU-207 마이크로 UX).
///
/// 규칙(디자인 시스템 MASTER §규칙 4): 소프트 삭제(보관·휴지통)는 **낙관적 실행 +
/// 실행 취소 토스트**, 영구 삭제는 **확인 시트**. 여기 세 도구가 그 규칙의 구현체다.
/// 화면이 제각기 SnackBar를 만들면 문구·길이·위치가 갈라진다 — 반드시 여기를 거친다.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/drop_theme.dart';

/// 햅틱. 웹·시뮬레이터에선 조용히 아무 일도 안 한다.
abstract final class DropHaptics {
  /// 상태를 고르거나 바꿨다 — 칩·체크박스·선택 토글.
  static void select() => HapticFeedback.selectionClick();

  /// 모드가 바뀌었다 — 선택 모드 진입, 복사 완료.
  static void impact() => HapticFeedback.mediumImpact();

  /// 되돌릴 수 없는 일을 했다.
  static void heavy() => HapticFeedback.heavyImpact();
}

/// 토스트. 한 줄만 말하고 사라진다. 되돌릴 수 있는 일이면 `actionLabel`로 되돌리기를 붙인다.
void showDropToast(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
  ScaffoldMessengerState? messenger,
}) => showDropToastOn(
  messenger ?? ScaffoldMessenger.of(context),
  message,
  actionLabel: actionLabel,
  onAction: onAction,
);

/// 화면을 닫은 **뒤**에 띄워야 할 때 쓴다 — 닫힌 화면의 context는 이미 죽어
/// 있으므로, 닫기 전에 붙잡아 둔 메신저에 직접 건다.
void showDropToastOn(
  ScaffoldMessengerState messenger,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
}) {
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: actionLabel == null ? 2 : 4),
        action: actionLabel == null
            ? null
            : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
      ),
    );
}

/// 확인 시트. 되돌릴 수 없는 일 앞에 한 번 멈춘다. 확인이면 true.
///
/// 다이얼로그가 아니라 바닥 시트인 이유: 엄지가 닿는 곳에 큰 버튼 둘로 서야
/// "잘못 눌러 지워지는" 일이 없다. 파괴적 확인 버튼은 danger 색.
Future<bool> showDropConfirmSheet(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  String cancelLabel = '취소',
  bool isDestructive = false,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    builder: (sheetContext) => _ConfirmSheet(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      isDestructive: isDestructive,
    ),
  );
  return result ?? false;
}

class _ConfirmSheet extends StatelessWidget {
  final String title;
  final String? message;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDestructive;

  const _ConfirmSheet({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.isDestructive,
  });

  @override
  Widget build(BuildContext context) {
    final colors = DropColors.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          DropLayout.gutter,
          DropTokenSpace.x2,
          DropLayout.gutter,
          DropTokenSpace.x3,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: DropText.sectionTitle.copyWith(color: colors.textPrimary),
            ),
            if (message != null) ...[
              const SizedBox(height: DropTokenSpace.x2),
              Text(
                message!,
                style: DropText.body.copyWith(color: colors.textSecondary),
              ),
            ],
            const SizedBox(height: DropTokenSpace.x5),
            SizedBox(
              height: DropLayout.controlHeight,
              child: FilledButton(
                style: isDestructive
                    ? FilledButton.styleFrom(
                        backgroundColor: colors.danger,
                        foregroundColor: colors.bgCard,
                      )
                    : null,
                onPressed: () {
                  if (isDestructive) DropHaptics.heavy();
                  Navigator.of(context).pop(true);
                },
                child: Text(confirmLabel),
              ),
            ),
            const SizedBox(height: DropTokenSpace.x2),
            SizedBox(
              height: DropLayout.controlHeight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(cancelLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
