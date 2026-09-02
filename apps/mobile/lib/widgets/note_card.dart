/// 목록의 한 줄. iOS `NoteCard`(DropUI) 대응.
///
/// 카드가 아니다 — 테두리도 바탕색도 없다. 행은 **제목 한 줄 + 메타 한 줄**이고,
/// 행과 행 사이는 여백만이 가른다. 위계는 굵기(제목 w500)와 색(메타 3차)으로 낸다.
library;

import 'package:drop_core/drop_core.dart';
import 'package:flutter/material.dart';

import '../theme/drop_theme.dart';
import 'note_group.dart';

class NoteCard extends StatelessWidget {
  final NoteRow row;
  final bool isSelecting;
  final bool isSelected;
  final int commentCount;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final VoidCallback onLongPress;

  /// 할일 체크박스를 눌렀을 때. 할일이 아닌 노트에는 체크박스를 그리지 않는다.
  final VoidCallback? onToggleCompleted;

  const NoteCard({
    super.key,
    required this.row,
    required this.isSelecting,
    required this.isSelected,
    required this.commentCount,
    required this.onTap,
    required this.onDoubleTap,
    required this.onLongPress,
    this.onToggleCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final note = row.note;
    final colors = DropColors.of(context);
    final now = DateTime.now();

    // 끝난 할일은 목록에서 사라지지 않고 흐려진다 — 방금 끝낸 것이
    // 눈앞에서 없어지면 무슨 일이 일어났는지 알 수 없다 (BRU-184).
    // 색은 AnimatedDefaultTextStyle이 미끄러지듯 바꾸고, 취소선은 Text가 직접 든다.
    final titleStyle = DropText.cardTitle.copyWith(
      color: note.isCompleted ? colors.textMuted : colors.textPrimary,
    );
    final strike = note.isCompleted
        ? TextStyle(
            decoration: TextDecoration.lineThrough,
            decorationColor: colors.textMuted,
          )
        : null;
    final metaStyle = DropText.meta.copyWith(color: colors.textTertiary);

    final leading = isSelecting
        ? _Control(
            icon: isSelected
                ? Icons.check_circle
                : Icons.radio_button_unchecked,
            color: isSelected ? colors.accent : colors.textMuted,
          )
        // 할일에만 그린다 (BRU-184). 선택 모드에서는 선택 동그라미와 겹치므로 뺀다.
        : note.isTodo
        ? GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onToggleCompleted,
            child: _Control(
              icon: note.isCompleted
                  ? Icons.check_box
                  : Icons.check_box_outline_blank,
              color: note.isCompleted ? colors.accent : colors.textMuted,
            ),
          )
        : null;
    final title = AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 180),
      style: titleStyle,
      child: Text(
        // 한 줄만 보이는 자리라 마크다운 기호를 걷어낸 평문 요약.
        MarkdownSummaryCache.summaryFor(note.content),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: strike,
      ),
    );

    // 제목 줄: [제목 ……] [시각]. 둘째 줄은 **말할 것이 있을 때만** — 댓글·첨부·태그.
    // 시각을 오른쪽 끝에 두면 왼쪽은 제목만 남아 훑기가 빨라지고, 둘째 줄이 없는
    // 노트는 한 줄로 끝나 목록이 조밀해진다. 핀 아이콘은 뺐다 — 고정 노트는 언제나
    // "고정" 묶음 안에 있어 아이콘이 같은 말을 두 번 한다.
    final hasMeta =
        note.attachments.isNotEmpty || commentCount > 0 || note.tags.isNotEmpty;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 부모를 잃고 최상위로 올라온 답글 — 독립 노트처럼 보이면 안 된다.
            if (row.isOrphanedReply)
              Padding(
                padding: const EdgeInsets.only(right: DropTokenSpace.x1),
                child: Icon(
                  Icons.subdirectory_arrow_right,
                  size: DropIconSize.inline,
                  color: colors.textTertiary,
                ),
              ),
            Expanded(child: title),
            const SizedBox(width: DropTokenSpace.x3),
            Text(
              relativeTimeString(note.createdAt, now: now),
              style: metaStyle,
            ),
          ],
        ),
        if (hasMeta) ...[
          const SizedBox(height: DropTokenSpace.x1),
          Row(
            children: [
              if (commentCount > 0)
                _count(Icons.mode_comment_outlined, commentCount, colors),
              if (note.attachments.isNotEmpty)
                _count(Icons.attach_file, note.attachments.length, colors),
              for (final tag in note.tags)
                Padding(
                  padding: const EdgeInsets.only(right: DropTokenSpace.x2),
                  child: Text(
                    '#${tag.name}',
                    style: metaStyle.copyWith(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );

    // 왼쪽 표식은 닿는 면이 44라 아이콘(22)보다 11씩 크다 — 거터에서 11을 물리고
    // 위로 (44 - 첫 줄 높이)/2 만큼 올려, **아이콘**이 거터 정렬선·첫 줄 중심에 앉게 한다.
    const controlBleed = (_Control.hitSize - DropIconSize.action) / 2;
    final firstLineHeight = DropTokenTextSize.lg * DropText.cardTitle.height!;
    return InkWell(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          // 묶음(NoteGroup) 안에 앉는 행이라 좌우는 묶음 안쪽 여백(16)이다.
          // 들여쓰기는 데이터상 깊이가 아니라 NoteHierarchy가 정한 **그릴 깊이**다.
          NoteGroup.inset +
              DropLayout.indent * row.depth -
              (leading == null ? 0 : controlBleed),
          DropLayout.rowPadding,
          NoteGroup.inset,
          DropLayout.rowPadding,
        ),
        // 필터에 걸린 게 아니라 자식의 맥락으로 끌어온 노트는 흐리게.
        child: Opacity(
          opacity: row.isContextOnly ? 0.5 : 1,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leading != null) ...[
                Transform.translate(
                  offset: Offset(0, -(_Control.hitSize - firstLineHeight) / 2),
                  child: leading,
                ),
                const SizedBox(width: DropTokenSpace.x3 - controlBleed),
              ],
              Expanded(child: content),
            ],
          ),
        ),
      ),
    );
  }

  Widget _count(IconData icon, int count, DropTokenColors colors) => Padding(
    padding: const EdgeInsets.only(right: DropTokenSpace.x2 + 2),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: DropIconSize.meta, color: colors.textTertiary),
        const SizedBox(width: 2),
        Text(
          '$count',
          style: DropText.meta.copyWith(color: colors.textTertiary),
        ),
      ],
    ),
  );
}

/// 행 왼쪽의 상태 표식. 아이콘은 22지만 **닿는 면은 44** — 손가락이 정확히
/// 아이콘을 맞출 필요가 없다. 바뀔 때는 커졌다 작아지며 갈아 끼워진다.
class _Control extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _Control({required this.icon, required this.color});

  static const double hitSize = 44;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: hitSize,
    height: hitSize,
    child: Center(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 160),
        switchInCurve: Curves.easeOutBack,
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: Icon(
          icon,
          key: ValueKey(icon),
          size: DropIconSize.action,
          color: color,
        ),
      ),
    ),
  );
}
