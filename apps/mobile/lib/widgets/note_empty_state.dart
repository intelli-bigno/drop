/// 목록이 빌 때 그 자리에 서는 것 (BRU-193에서 HomeScreen 밖으로 꺼냄).
///
/// 원래 `HomeScreen._emptyState`라는 private 메서드였다. 그래서 빈 상태를
/// 눈으로 보려면 계정에 노트가 하나도 없어야 했고, 쇼케이스도 테스트도
/// 그 자리에 닿지 못했다. 화면이 못 보여 주는 상태는 결국 방치된다.
library;

import 'package:drop_core/drop_core.dart';
import 'package:flutter/material.dart';

import '../theme/drop_theme.dart';

class NoteEmptyState extends StatelessWidget {
  final NoteViewMode viewMode;

  /// 검색 중이면 뷰 모드보다 검색이 이긴다 — "휴지통이 비어 있습니다"는
  /// 검색어를 지우면 결과가 나온다는 사실을 숨긴다.
  final bool isSearching;

  const NoteEmptyState({
    super.key,
    required this.viewMode,
    this.isSearching = false,
  });

  String get message => isSearching
      ? '검색 결과가 없습니다'
      : switch (viewMode) {
          NoteViewMode.active => '아직 노트가 없습니다',
          NoteViewMode.archived => '보관한 노트가 없습니다',
          NoteViewMode.trash => '휴지통이 비어 있습니다',
        };

  IconData get icon => switch (viewMode) {
        NoteViewMode.active => Icons.inbox_outlined,
        NoteViewMode.archived => Icons.archive_outlined,
        NoteViewMode.trash => Icons.delete_outline,
      };

  @override
  Widget build(BuildContext context) {
    final colors = DropColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: DropIconSize.empty, color: colors.textTertiary),
        const SizedBox(height: DropTokenSpace.x2),
        Text(
          message,
          style: DropText.body.copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }
}
