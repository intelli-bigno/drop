/// 한 노트의 댓글을 읽고 쓰는 시트. iOS `CommentsSheet.swift` 대응.
///
/// 시트로 띄우는 이유(iOS와 같다): 댓글은 노트를 보다가 잠깐 덧붙이는 것이지
/// 다른 화면으로 넘어가는 일이 아니다. 뷰어 → 댓글 → 닫기로 원래 자리에 돌아온다.
/// 개인 앱이라 작성자 표기는 없다 — 본문과 상대 시간만 그린다.
library;

import 'package:drop_core/drop_core.dart';
import 'package:flutter/material.dart';

import '../notes/comments_controller.dart';
import '../theme/drop_theme.dart';
import '../widgets/drop_action_sheet.dart';
import '../widgets/drop_feedback.dart';
import '../widgets/drop_notice.dart';

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

  const CommentsSheet({
    super.key,
    required this.note,
    required this.controller,
  });

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final _draft = TextEditingController();
  final _scroll = ScrollController();
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
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = DropColors.of(context);
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final count = widget.controller.commentsFor(widget.note.id).length;
        return Column(
          children: [
            DropSheetHeader(
              title: '댓글',
              subtitle: count > 0 ? '$count' : null,
              onClose: () => Navigator.of(context).pop(),
            ),
            // 어느 노트에 다는 댓글인지 늘 보이게 둔다 — 시트만 보면 맥락이 사라진다.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DropLayout.gutter,
                0,
                DropLayout.gutter,
                DropTokenSpace.x3,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.note.content.isEmpty
                      ? '빈 노트'
                      : MarkdownSummaryCache.summaryFor(widget.note.content),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DropText.meta.copyWith(color: colors.textTertiary),
                ),
              ),
            ),
            if (widget.controller.errorMessage != null)
              DropNotice(
                message: widget.controller.errorMessage!,
                onDismiss: widget.controller.dismissError,
              ),
            Expanded(child: _list(colors)),
            _composer(colors),
          ],
        );
      },
    );
  }

  Widget _list(DropTokenColors colors) {
    final comments = widget.controller.commentsFor(widget.note.id);
    if (comments.isEmpty) {
      if (widget.controller.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '댓글이 없습니다',
              style: DropText.cardTitle.copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: DropTokenSpace.x2),
            Text(
              '이 노트에 덧붙일 말을 아래에 적어 보세요',
              style: DropText.body.copyWith(color: colors.textTertiary),
            ),
          ],
        ),
      );
    }
    final now = DateTime.now();
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.only(bottom: DropTokenSpace.x4),
      children: [
        for (final comment in comments)
          // 댓글에는 휴지통이 없다 — 지우면 바로 사라진다 (하드 삭제).
          // 되돌릴 수 없으니 스와이프 끝에서 한 번 묻는다.
          Dismissible(
            key: ValueKey('comment-${comment.id}'),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) => showDropConfirmSheet(
              context,
              title: '이 댓글을 지울까요?',
              message: '지운 댓글은 되돌릴 수 없어요.',
              confirmLabel: '지우기',
              isDestructive: true,
            ),
            background: Container(
              color: colors.danger,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: DropLayout.gutter),
              child: Icon(Icons.delete, color: colors.bgCard),
            ),
            onDismissed: (_) => widget.controller.delete(
              id: comment.id,
              noteId: widget.note.id,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DropLayout.gutter,
                vertical: DropLayout.rowPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    comment.body,
                    style: DropText.reading.copyWith(color: colors.textPrimary),
                  ),
                  const SizedBox(height: DropTokenSpace.x1),
                  Text(
                    relativeTimeString(comment.createdAt, now: now),
                    style: DropText.meta.copyWith(color: colors.textTertiary),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// 입력 줄 — 눌러 넣은 면 하나에 글자와 보내기가 함께 앉는다.
  Widget _composer(DropTokenColors colors) {
    final canSend = !_isSending && _draft.text.trim().isNotEmpty;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          DropLayout.gutter,
          DropTokenSpace.x2,
          DropLayout.gutter,
          DropTokenSpace.x3,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            DropTokenSpace.x4,
            DropTokenSpace.x1,
            DropTokenSpace.x1,
            DropTokenSpace.x1,
          ),
          decoration: BoxDecoration(
            color: colors.surfaceField,
            borderRadius: BorderRadius.circular(DropRadius.control + 6),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _draft,
                  minLines: 1,
                  maxLines: 4,
                  style: DropText.body.copyWith(color: colors.textPrimary),
                  decoration: InputDecoration(
                    hintText: '댓글 쓰기',
                    hintStyle: DropText.body.copyWith(color: colors.textMuted),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: DropTokenSpace.x3,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              IconButton(
                tooltip: '댓글 보내기',
                icon: const Icon(Icons.arrow_upward),
                style: IconButton.styleFrom(
                  backgroundColor: canSend ? colors.accent : colors.borderColor,
                  foregroundColor: colors.textOnAccent,
                  disabledBackgroundColor: colors.borderColor,
                  disabledForegroundColor: colors.textMuted,
                  minimumSize: const Size(
                    DropLayout.chipHeight,
                    DropLayout.chipHeight,
                  ),
                  padding: EdgeInsets.zero,
                ),
                // 보내는 중 중복 탭을 막지 않으면 같은 댓글이 두 번 올라간다.
                onPressed: canSend ? _send : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _send() async {
    final body = _draft.text.trim();
    if (body.isEmpty) return;
    setState(() {
      _isSending = true;
      // 입력창은 즉시 비운다 — 낙관적 삽입과 같은 이유로, 보낸 것이 두 군데
      // 남아 있으면 방금 무엇을 썼는지 헷갈린다.
      _draft.clear();
    });
    DropHaptics.select();
    await widget.controller.add(noteId: widget.note.id, body: body);
    if (!mounted) return;
    setState(() => _isSending = false);
    // 새 댓글은 맨 아래에 붙는다 — 보이는 곳까지 내려가 준다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
      }
    });
  }
}
