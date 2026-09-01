/// Patterns — 노트 행이 모여 목록이 되는 규칙 (BRU-193).
/// 데스크톱 `styleguide/sections/Patterns.tsx` 대응.
///
/// Components가 물건 하나씩이라면 여기는 **물건들이 놓이는 방식**이다 —
/// 날짜 묶음의 리듬, 답글 들여쓰기, 맥락으로 끌려온 노트의 흐림.
library;

import 'package:drop_core/drop_core.dart';
import 'package:flutter/material.dart';

import '../../theme/drop_theme.dart';
import '../../widgets/note_card.dart';
import '../../widgets/note_section_header.dart';
import '../fixtures.dart';
import '../parts.dart';

class PatternsSection extends StatelessWidget {
  const PatternsSection({super.key});

  static const _grouper = NoteDateGrouper();

  @override
  Widget build(BuildContext context) {
    final sections = _grouper.sections(showcaseRows);

    return ListView(
      padding: const EdgeInsets.all(DropTokenSpace.x5),
      children: [
        const PageHead(
          title: 'Patterns',
          lede: '행 하나가 아니라 행들이 놓이는 방식이다. 묶기·들여쓰기·흐림은 전부 '
              'drop_core의 순수 로직이 정하고 화면은 그리기만 한다.',
        ),
        Specimen(
          name: '날짜 묶음',
          desc: 'NoteDateGrouper가 나눈 그대로 — 머리글은 실제 위젯이다',
          file: 'lib/widgets/note_section_header.dart',
          phone: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final section in sections) ...[
                NoteSectionHeader(title: section.title),
                for (final row in section.rows)
                  NoteCard(
                    row: row,
                    isSelecting: false,
                    isSelected: false,
                    commentCount: 0,
                    onTap: () {},
                    onDoubleTap: () {},
                    onLongPress: () {},
                    onToggleCompleted: () {},
                  ),
              ],
            ],
          ),
        ),
        Specimen(
          name: '계층 — 답글 들여쓰기',
          desc: 'depth는 데이터상 깊이가 아니라 그릴 깊이다 (상한에서 멈춘다)',
          file: 'packages/drop_core/lib/src/note_hierarchy.dart',
          phone: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var depth = 0; depth <= 3; depth += 1)
                NoteCard(
                  row: NoteRow(
                    note: depth == 0 ? noteLong : replyChild,
                    depth: depth,
                  ),
                  isSelecting: false,
                  isSelected: false,
                  commentCount: 0,
                  onTap: () {},
                  onDoubleTap: () {},
                  onLongPress: () {},
                ),
            ],
          ),
        ),
        Specimen(
          name: '맥락으로 끌려온 노트',
          desc: '필터에 걸린 게 아니라 자식을 보여 주려 끌어온 부모 — 흐리게',
          file: 'lib/widgets/note_card.dart',
          phone: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NoteCard(
                row: NoteRow(note: noteLong, depth: 0, isContextOnly: true),
                isSelecting: false,
                isSelected: false,
                commentCount: 0,
                onTap: () {},
                onDoubleTap: () {},
                onLongPress: () {},
              ),
              NoteCard(
                row: NoteRow(note: replyChild, depth: 1),
                isSelecting: false,
                isSelected: false,
                commentCount: 0,
                onTap: () {},
                onDoubleTap: () {},
                onLongPress: () {},
              ),
            ],
          ),
        ),
        Specimen(
          name: '부모를 잃은 답글',
          desc: '최상위로 올라왔지만 독립 노트처럼 보이면 안 된다 — 화살표 표식',
          file: 'lib/widgets/note_card.dart',
          phone: true,
          child: NoteCard(
            row: NoteRow(note: replyChild, depth: 0, isOrphanedReply: true),
            isSelecting: false,
            isSelected: false,
            commentCount: 0,
            onTap: () {},
            onDoubleTap: () {},
            onLongPress: () {},
          ),
        ),
        Specimen(
          name: '할일 — 남은 것과 끝난 것',
          desc: '끝난 할일은 사라지지 않고 흐려진다 (BRU-184)',
          file: 'lib/widgets/note_card.dart',
          phone: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final note in [todoOpen, todoDone])
                NoteCard(
                  row: NoteRow(note: note, depth: 0),
                  isSelecting: false,
                  isSelected: false,
                  commentCount: 0,
                  onTap: () {},
                  onDoubleTap: () {},
                  onLongPress: () {},
                  onToggleCompleted: () {},
                ),
            ],
          ),
        ),
      ],
    );
  }
}
