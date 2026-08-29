/// 목록의 한 줄. iOS `NoteCard`(DropUI) 대응 — 여기는 Material 기본값으로 그린다.
/// 토큰 스타일링은 BRU-159 몫이다.
library;

import 'package:drop_core/drop_core.dart';
import 'package:flutter/material.dart';

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
    final theme = Theme.of(context);
    final now = DateTime.now();

    final card = Padding(
      // 들여쓰기는 데이터상 깊이가 아니라 NoteHierarchy가 정한 **그릴 깊이**다.
      padding: EdgeInsets.only(left: 16.0 * row.depth),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isSelecting)
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 2),
              child: Icon(
                isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 20,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
            ),
          // 할일에만 그린다 (BRU-184). 일반 노트에도 있으면 "이 노트도 끝낼 수
          // 있는 것"으로 읽힌다. 선택 모드에서는 선택 동그라미와 겹치므로 뺀다.
          if (note.isTodo && !isSelecting)
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 1),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onToggleCompleted,
                child: Icon(
                  note.isCompleted
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  size: 20,
                  color: note.isCompleted
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (note.isPinned)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(Icons.push_pin, size: 14),
                      ),
                    // 부모를 잃고 최상위로 올라온 답글 — 독립 노트처럼 보이면 안 된다.
                    if (row.isOrphanedReply)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(Icons.subdirectory_arrow_right, size: 14),
                      ),
                    Expanded(
                      child: Text(
                        // 한 줄만 보이는 자리라 마크다운 기호를 걷어낸 평문 요약.
                        MarkdownSummaryCache.summaryFor(note.content),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        // 끝난 할일은 목록에서 사라지지 않고 흐려진다 —
                        // 방금 끝낸 것이 눈앞에서 없어지면 무슨 일이
                        // 일어났는지 알 수 없다 (BRU-184).
                        style: note.isCompleted
                            ? theme.textTheme.bodyMedium?.copyWith(
                                decoration: TextDecoration.lineThrough,
                                color: theme.colorScheme.outline,
                              )
                            : theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      relativeTimeString(note.createdAt, now: now),
                      style: theme.textTheme.bodySmall,
                    ),
                    if (note.attachments.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.attach_file, size: 13),
                      Text(
                        '${note.attachments.length}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    // 0이면 뱃지를 그리지 않는다.
                    if (commentCount > 0) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.mode_comment_outlined, size: 13),
                      Text('$commentCount', style: theme.textTheme.bodySmall),
                    ],
                    for (final tag in note.tags) ...[
                      const SizedBox(width: 8),
                      Text('#${tag.name}', style: theme.textTheme.bodySmall),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        // 필터에 걸린 게 아니라 자식의 맥락으로 끌어온 노트는 흐리게.
        child: Opacity(opacity: row.isContextOnly ? 0.5 : 1, child: card),
      ),
    );
  }
}
