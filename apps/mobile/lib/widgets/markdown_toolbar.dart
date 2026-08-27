/// 작성 시트의 마크다운 입력 보조 (BRU-37). DropUI `MarkdownToolbar.swift` 대응.
///
/// 모바일 키보드에는 `#`도 `*`도 한 단계 들어가 있다 — 그 기호를 손으로 치게 두면
/// 마크다운은 "쓸 수는 있지만 아무도 안 쓰는 기능"이 된다.
library;

import 'package:drop_core/drop_core.dart';
import 'package:flutter/material.dart';

class MarkdownToolbar extends StatelessWidget {
  /// 툴바에 세울 명령과 그 얼굴. 순서가 곧 화면 순서다 — iOS와 같다.
  static const _items = <(MarkdownEditingCommand, IconData, String)>[
    (MarkdownEditingCommand.heading, Icons.title, '제목'),
    (MarkdownEditingCommand.bold, Icons.format_bold, '굵게'),
    (MarkdownEditingCommand.italic, Icons.format_italic, '기울임'),
    (MarkdownEditingCommand.bulletList, Icons.format_list_bulleted, '목록'),
    (MarkdownEditingCommand.checkbox, Icons.checklist, '체크박스'),
    (MarkdownEditingCommand.code, Icons.code, '코드'),
    (MarkdownEditingCommand.quote, Icons.format_quote, '인용'),
    (MarkdownEditingCommand.link, Icons.link, '링크'),
  ];

  final ValueChanged<MarkdownEditingCommand> onCommand;

  const MarkdownToolbar({super.key, required this.onCommand});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      // 좁은 화면에서 버튼이 줄어들거나 잘리는 대신 옆으로 넘어가게 둔다.
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          for (final (command, icon, label) in _items)
            IconButton(
              tooltip: label,
              icon: Icon(icon, size: 20),
              onPressed: () => onCommand(command),
            ),
        ],
      ),
    );
  }
}
