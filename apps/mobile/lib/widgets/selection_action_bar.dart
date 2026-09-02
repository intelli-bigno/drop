/// 선택 모드의 일괄 동작 줄. iOS `SelectionActionBar.swift` 대응.
/// 보고 있는 뷰 모드에 따라 할 수 있는 일이 달라진다 — 휴지통에서 "보관"은 뜻이 없다.
library;

import 'package:drop_core/drop_core.dart';
import 'package:flutter/material.dart';

import '../notes/notes_controller.dart';
import '../theme/drop_theme.dart';
import 'drop_feedback.dart';

class SelectionActionBar extends StatelessWidget {
  final NotesController controller;

  const SelectionActionBar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final colors = DropColors.of(context);
    final actions = switch (controller.store.viewMode) {
      NoteViewMode.active => [
        _action(
          '보관',
          Icons.archive_outlined,
          (context) => _soft(
            context,
            perform: controller.archiveSelected,
            undo: controller.unarchive,
            message: (n) => '$n개를 보관했어요',
          ),
        ),
        _action(
          '삭제',
          Icons.delete_outline,
          (context) => _soft(
            context,
            perform: controller.trashSelected,
            undo: controller.restore,
            message: (n) => '$n개를 휴지통으로 옮겼어요',
          ),
          isDestructive: true,
        ),
      ],
      NoteViewMode.archived => [
        _action(
          '복원',
          Icons.undo,
          (context) => _soft(
            context,
            perform: controller.unarchiveSelected,
            undo: controller.archive,
            message: (n) => '$n개를 복원했어요',
          ),
        ),
        _action(
          '삭제',
          Icons.delete_outline,
          (context) => _soft(
            context,
            perform: controller.trashSelected,
            undo: controller.restore,
            message: (n) => '$n개를 휴지통으로 옮겼어요',
          ),
          isDestructive: true,
        ),
      ],
      NoteViewMode.trash => [
        _action(
          '복원',
          Icons.undo,
          (context) => _soft(
            context,
            perform: controller.restoreSelected,
            undo: controller.moveToTrash,
            message: (n) => '$n개를 복원했어요',
          ),
        ),
        _action(
          '영구 삭제',
          Icons.delete_forever_outlined,
          _deleteForever,
          isDestructive: true,
        ),
      ],
    };

    // 오버레이 층 — 목록 위에 얹힌 도구 줄이라 바탕보다 한 단 밝고, 위쪽에
    // 실선 하나로 경계를 긋는다.
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceOverlay,
        border: Border(top: BorderSide(color: colors.borderSubtle)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: DropTokenSpace.x2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [for (final action in actions) action(context)],
          ),
        ),
      ),
    );
  }

  /// 소프트 동작: 바로 실행하고, 토스트로 되돌리기를 준다 (MASTER §규칙 4).
  /// 선택은 실행 직후 풀리므로 id를 **먼저** 붙잡아 둔다.
  Future<void> _soft(
    BuildContext context, {
    required Future<void> Function() perform,
    required Future<void> Function(String id) undo,
    required String Function(int count) message,
  }) async {
    final ids = controller.store.selectedIds.toList();
    if (ids.isEmpty) return;
    DropHaptics.select();
    await perform();
    if (!context.mounted) return;
    showDropToast(
      context,
      message(ids.length),
      actionLabel: '실행 취소',
      onAction: () async {
        for (final id in ids) {
          await undo(id);
        }
      },
    );
  }

  /// 영구 삭제만은 되돌릴 수 없으니 한 번 묻는다.
  Future<void> _deleteForever(BuildContext context) async {
    final count = controller.store.selectedIds.length;
    if (count == 0) return;
    final ok = await showDropConfirmSheet(
      context,
      title: '$count개를 영구 삭제할까요?',
      message: '휴지통에서도 사라지고 되돌릴 수 없어요.',
      confirmLabel: '삭제',
      isDestructive: true,
    );
    if (!ok) return;
    await controller.deleteSelectedPermanently();
    if (context.mounted) showDropToast(context, '$count개를 삭제했어요');
  }

  Widget Function(BuildContext) _action(
    String title,
    IconData icon,
    Future<void> Function(BuildContext context) perform, {
    bool isDestructive = false,
  }) => (context) {
    final colors = DropColors.of(context);
    final color = isDestructive ? colors.danger : colors.textPrimary;
    return TextButton(
      onPressed: () => perform(context),
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(
          horizontal: DropLayout.gutter,
          vertical: DropTokenSpace.x2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: DropIconSize.action, color: color),
          const SizedBox(height: DropTokenSpace.x1),
          Text(title, style: DropText.caption.copyWith(color: color)),
        ],
      ),
    );
  };
}
