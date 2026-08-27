/// 한 노트의 댓글을 읽고 쓰는 시트. iOS `CommentsSheet.swift` 대응.
///
/// 시트로 띄우는 이유(iOS와 같다): 댓글은 노트를 보다가 잠깐 덧붙이는 것이지
/// 다른 화면으로 넘어가는 일이 아니다. 뷰어 → 댓글 → 닫기로 원래 자리에 돌아온다.
/// 개인 앱이라 작성자 표기는 없다 — 본문과 상대 시간만 그린다.
library;

import 'package:drop_core/drop_core.dart';
import 'package:flutter/material.dart';

import '../notes/comments_controller.dart';

Future<void> showCommentsSheet(
  BuildContext context, {
  required Note note,
  required CommentsController controller,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (sheetContext) => Padding(
    // 키보드가 올라오면 입력 바가 함께 올라와야 한다.
    padding: EdgeInsets.only(
      bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
    ),
    child: FractionallySizedBox(
      heightFactor: 0.9,
      child: CommentsSheet(note: note, controller: controller),
    ),
  ),
);

class CommentsSheet extends StatefulWidget {
  final Note note;
  final CommentsController controller;

  const CommentsSheet({super.key, required this.note, required this.controller});

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final _draft = TextEditingController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    // 시트를 열 때마다 새로 불러온다 — 실패해도 이미 받아 둔 목록은 남는다 (BRU-51).
    widget.controller.loadFor(widget.note.id);
  }

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => Column(
        children: [
          _header(theme),
          if (widget.controller.errorMessage != null)
            MaterialBanner(
              content: Text(widget.controller.errorMessage!),
              actions: [
                TextButton(
                  onPressed: widget.controller.dismissError,
                  child: const Text('확인'),
                ),
              ],
            ),
          Expanded(child: _list(theme)),
          const Divider(height: 1),
          _composer(theme),
        ],
      ),
    );
  }

  /// 어느 노트에 다는 댓글인지 늘 보이게 둔다 — 시트만 보면 맥락이 사라진다.
  Widget _header(ThemeData theme) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('댓글', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              widget.note.content.isEmpty
                  ? '빈 노트'
                  : MarkdownSummaryCache.summaryFor(widget.note.content),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      );

  Widget _list(ThemeData theme) {
    final comments = widget.controller.commentsFor(widget.note.id);
    if (comments.isEmpty) {
      if (widget.controller.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mode_comment_outlined, size: 40),
            const SizedBox(height: 8),
            Text('댓글이 없습니다', style: theme.textTheme.bodyMedium),
          ],
        ),
      );
    }
    final now = DateTime.now();
    return ListView(
      children: [
        for (final comment in comments)
          // 댓글에는 휴지통이 없다 — 지우면 바로 사라진다 (하드 삭제).
          Dismissible(
            key: ValueKey('comment-${comment.id}'),
            direction: DismissDirection.endToStart,
            background: Container(
              color: theme.colorScheme.error,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: Icon(Icons.delete, color: theme.colorScheme.onError),
            ),
            onDismissed: (_) => widget.controller
                .delete(id: comment.id, noteId: widget.note.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(comment.body, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 2),
                  Text(
                    relativeTimeString(comment.createdAt, now: now),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _composer(ThemeData theme) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _draft,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: '댓글 쓰기',
                  border: InputBorder.none,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            IconButton(
              tooltip: '댓글 보내기',
              icon: const Icon(Icons.arrow_circle_up),
              // 보내는 중 중복 탭을 막지 않으면 같은 댓글이 두 번 올라간다.
              onPressed:
                  _isSending || _draft.text.trim().isEmpty ? null : _send,
            ),
          ],
        ),
      );

  Future<void> _send() async {
    final body = _draft.text.trim();
    if (body.isEmpty) return;
    setState(() {
      _isSending = true;
      // 입력창은 즉시 비운다 — 낙관적 삽입과 같은 이유로, 보낸 것이 두 군데
      // 남아 있으면 방금 무엇을 썼는지 헷갈린다.
      _draft.clear();
    });
    await widget.controller.add(noteId: widget.note.id, body: body);
    if (mounted) setState(() => _isSending = false);
  }
}
