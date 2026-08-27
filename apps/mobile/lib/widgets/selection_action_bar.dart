/// 선택 모드의 일괄 동작 줄. iOS `SelectionActionBar.swift` 대응.
/// 보고 있는 뷰 모드에 따라 할 수 있는 일이 달라진다 — 휴지통에서 "보관"은 뜻이 없다.
library;

import 'package:drop_core/drop_core.dart';
import 'package:flutter/material.dart';

import '../notes/notes_controller.dart';

class SelectionActionBar extends StatelessWidget {
  final NotesController controller;

  const SelectionActionBar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final actions = switch (controller.store.viewMode) {
      NoteViewMode.active => [
        _action('보관', Icons.archive_outlined, controller.archiveSelected),
        _action(
          '삭제',
          Icons.delete_outline,
          controller.trashSelected,
          isDestructive: true,
        ),
      ],
      NoteViewMode.archived => [
        _action('복원', Icons.undo, controller.unarchiveSelected),
        _action(
          '삭제',
          Icons.delete_outline,
          controller.trashSelected,
          isDestructive: true,
        ),
      ],
      NoteViewMode.trash => [
        _action('복원', Icons.undo, controller.restoreSelected),
        _action(
          '영구 삭제',
          Icons.delete_forever_outlined,
          controller.deleteSelectedPermanently,
          isDestructive: true,
        ),
      ],
    };

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [for (final action in actions) action(context)],
        ),
      ),
    );
  }

  Widget Function(BuildContext) _action(
    String title,
    IconData icon,
    Future<void> Function() perform, {
    bool isDestructive = false,
  }) => (context) {
    final color = isDestructive ? Theme.of(context).colorScheme.error : null;
    return TextButton(
      onPressed: perform,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: color),
          Text(title, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  };
}
