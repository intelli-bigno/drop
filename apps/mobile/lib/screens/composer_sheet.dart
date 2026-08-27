/// 새 노트 컴포저 **스텁**. 진짜 컴포저(마크다운 툴바·첨부)는 BRU-158이다 —
/// 그쪽 작업은 이 함수 하나를 갈아끼우면 된다.
library;

import 'package:flutter/material.dart';

import '../notes/notes_controller.dart';

Future<void> showComposerSheet(
  BuildContext context,
  NotesController controller,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (sheetContext) => Padding(
    padding: EdgeInsets.only(
      left: 16,
      right: 16,
      top: 16,
      bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
    ),
    child: _ComposerStub(controller: controller),
  ),
);

class _ComposerStub extends StatefulWidget {
  final NotesController controller;

  const _ComposerStub({required this.controller});

  @override
  State<_ComposerStub> createState() => _ComposerStubState();
}

class _ComposerStubState extends State<_ComposerStub> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _text,
          autofocus: true,
          maxLines: 5,
          minLines: 1,
          decoration: const InputDecoration(hintText: '무엇이든 적어 두세요'),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () {
            final content = _text.text.trim();
            Navigator.of(context).pop();
            if (content.isEmpty) return;
            widget.controller.create(content: content);
          },
          child: const Text('저장'),
        ),
      ],
    );
  }
}
