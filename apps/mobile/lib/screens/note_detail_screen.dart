/// 노트를 **펼쳐 읽는** 자리 (BRU-77 · BRU-157). iOS `NoteDetailView.swift` 대응.
///
/// 이 화면은 읽기 전용이다. 여기에는 저장 호출이 없다 — 본문이 서버로 나가는
/// 유일한 길은 "편집"을 눌러 여는 컴포저뿐이다. 열고 닫는 것만으로는 아무것도
/// 저장되지 않는다 — 데스크톱에서 "펼치기만 해도 원문이 덮어써지던" 사고(BRU-66)의
/// 재발 방지.
///
/// 어떤 동작이 가능한지는 `NoteViewerAction.actionsFor(note)`가 정한다 —
/// 화면이 제 사정으로 버튼을 붙이면 휴지통 노트에 "휴지통으로"가 붙는 식으로 어긋난다.
///
/// BRU-207 — 읽는 화면이라 본문을 `reading` 역할로 키우고, 메타(시각·수정)는
/// 한 줄로 합쳤다. 상태 변경은 팝업 메뉴 대신 바닥 시트로 올린다.
library;

import 'package:drop_core/drop_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../environment/providers.dart';
import '../notes/comments_controller.dart';
import '../notes/notes_controller.dart';
import '../theme/drop_theme.dart';
import '../widgets/attachment_thumbnail.dart';
import '../widgets/drop_feedback.dart';
import '../widgets/markdown_view.dart';
import '../widgets/note_group.dart';
import 'comments_sheet.dart';
import 'composer_sheet.dart';
import 'media_viewer_screen.dart';

class NoteDetailScreen extends ConsumerWidget {
  final String noteId;

  /// 목록과 같은 컨트롤러를 보는 스코프 키. 홈이 라우트 extra로 넘긴다.
  final String? userId;

  const NoteDetailScreen({super.key, required this.noteId, this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final container = ref.watch(dropContainerProvider);
    final notes = ref.watch(notesControllerProvider(userId));
    final comments = ref.watch(commentsControllerProvider(userId));
    final colors = DropColors.of(context);
    // 노트를 통째로 들고 있으면 편집 저장 뒤에도 옛 값이 남는다 —
    // id만 들고 목록에서 매번 찾는다 (BRU-77과 같은 태도).
    final matches = notes.store.allNotes
        .where((note) => note.id == noteId)
        .toList();
    final note = matches.isEmpty ? null : matches.first;

    Future<Uri?> urlFor(Attachment attachment) async {
      try {
        return await container.attachmentsRepository.signedUrl(
          attachment.storagePath,
        );
      } catch (_) {
        // 프리뷰(스토리지 없음)·네트워크 실패 — 화면은 자리표시로 그린다.
        return null;
      }
    }

    final actions = note == null
        ? const <NoteViewerAction>[]
        : NoteViewerAction.actionsFor(note);

    return Scaffold(
      appBar: AppBar(
        title: Text(note == null ? '노트' : '#${note.displayId}'),
        // 할 수 있는 일을 ⋯ 안에 감추지 않고 **하나씩 꺼내 세운다** (BRU-207 피드백).
        // 무엇을 할 수 있는지는 여전히 `NoteViewerAction.actionsFor`가 정한다 —
        // 휴지통 노트에 '휴지통으로'가 붙는 식으로 어긋나지 않는다.
        //
        // 편집만 여기 없다 — 가장 자주 쓰는 하나라 엄지가 닿는 오른쪽 아래
        // 플로팅 버튼으로 내려갔다. 위에 남은 것은 가끔 쓰는 상태 변경뿐이다.
        actions: [
          if (note != null)
            for (final action in actions)
              if (action != NoteViewerAction.comments &&
                  action != NoteViewerAction.edit)
                _actionButton(context, notes, note, action),
          const SizedBox(width: DropTokenSpace.x1),
        ],
      ),
      body: note == null
          ? Center(
              child: Text(
                '노트를 찾을 수 없습니다',
                style: DropText.body.copyWith(color: colors.textSecondary),
              ),
            )
          : SingleChildScrollView(
              // 좌우 여백은 조각마다 스스로 준다 — 부속 묶음(NoteGroup)이
              // 제 거터를 들고 있어서 여기서 또 주면 두 번 밀린다.
              padding: const EdgeInsets.only(
                top: DropTokenSpace.x1,
                // 마지막 줄이 플로팅 편집 버튼 밑에 깔리지 않게 한 뼘 더 둔다.
                bottom: DropTokenSpace.x8 + DropTokenSpace.x6,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DropLayout.gutter,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _header(context, note),
                        _todoToggle(context, notes, note),
                        _checklistBar(context, note),
                        const SizedBox(height: DropTokenSpace.x5),
                        _content(context, notes, note),
                      ],
                    ),
                  ),
                  const SizedBox(height: DropTokenSpace.x6),
                  _footerGroup(context, note, comments, urlFor),
                ],
              ),
            ),
      // 편집은 이 화면에서 가장 자주 누르는 하나다 — 홈의 '새 노트'와 같은 자리,
      // 같은 색으로 두어 "여기서 쓰기 시작한다"가 한 몸으로 읽힌다.
      floatingActionButton:
          note != null && actions.contains(NoteViewerAction.edit)
          ? FloatingActionButton(
              tooltip: '편집',
              onPressed: () => showComposerSheet(
                context,
                notes,
                target: ComposerTarget.existing(note),
              ),
              child: const Icon(Icons.edit_outlined),
            )
          : null,
    );
  }

  // 조각

  /// 시각. 고친 적이 있으면 같은 줄 끝에 붙인다 — 뷰어만 열었을 때 이 값이
  /// 움직이지 않는다는 것이 이 화면의 계약이다 (BRU-77 완료 기준).
  Widget _header(BuildContext context, Note note) {
    final colors = DropColors.of(context);
    final metaStyle = DropText.meta.copyWith(color: colors.textTertiary);
    final wasEdited = note.updatedAt.difference(note.createdAt).inSeconds > 1;
    return Row(
      children: [
        if (note.isPinned)
          Padding(
            padding: const EdgeInsets.only(right: DropTokenSpace.x1),
            child: Icon(
              Icons.push_pin,
              size: DropIconSize.inline,
              color: colors.accent,
            ),
          ),
        Expanded(
          child: Text.rich(
            TextSpan(
              text: _absoluteTime(note.createdAt),
              children: [
                if (wasEdited)
                  TextSpan(
                    text:
                        '  ·  수정 ${relativeTimeString(note.updatedAt, now: DateTime.now())}',
                  ),
              ],
            ),
            style: metaStyle,
          ),
        ),
      ],
    );
  }

  /// 본문 전문 — 마크다운을 drop_core 파서 결과 그대로 그린다.
  ///
  /// 본문이 여기서 바뀌는 길은 **체크박스 하나뿐**이다 (BRU-207). 어느 줄을
  /// 고칠지는 파서가 알려 주고 무엇으로 바꿀지는 `MarkdownChecklist`가 정한다 —
  /// 화면은 결과를 저장만 한다.
  Widget _content(BuildContext context, NotesController notes, Note note) {
    if (note.content.isEmpty) {
      final colors = DropColors.of(context);
      return Text(
        '빈 노트',
        style: DropText.reading.copyWith(color: colors.textMuted),
      );
    }
    return SelectionArea(
      child: MarkdownView(
        source: note.content,
        onToggleCheckbox: (content) =>
            notes.update(id: note.id, content: content),
      ),
    );
  }

  /// 체크박스가 있으면 그 진행을 맨 위에 한 줄로 세운다 — 본문을 다 읽지 않고도
  /// "얼마나 남았나"가 보여야 한다. 없으면 아무것도 그리지 않는다.
  Widget _checklistBar(BuildContext context, Note note) {
    final progress = MarkdownChecklist.progress(note.content);
    if (progress.isEmpty) return const SizedBox.shrink();

    final colors = DropColors.of(context);
    final done = progress.isComplete;
    return Padding(
      padding: const EdgeInsets.only(top: DropTokenSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                done ? '다 끝냈어요' : '할일',
                style: DropText.label.copyWith(
                  color: done ? colors.accent : colors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                '${progress.completed} / ${progress.total}',
                style: DropText.label.copyWith(
                  color: done ? colors.accent : colors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: DropTokenSpace.x2),
          ClipRRect(
            borderRadius: BorderRadius.circular(DropTokenSpace.x1),
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOut,
              tween: Tween(begin: 0, end: progress.fraction),
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: colors.surfaceField,
                color: colors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 노트 자체가 할일이면 여기서 끝낼 수 있어야 한다 — 이게 없으면 뒤로 나가
  /// 목록에서 눌러야 했다 (BRU-207). 본문이 아니라 **상태**를 바꾸는 일이라
  /// 뷰어의 읽기 전용 계약(BRU-77)과 부딪히지 않는다.
  Widget _todoToggle(BuildContext context, NotesController notes, Note note) {
    if (!note.isTodo) return const SizedBox.shrink();

    final colors = DropColors.of(context);
    final done = note.isCompleted;
    return Padding(
      padding: const EdgeInsets.only(top: DropTokenSpace.x4),
      child: Material(
        color: done ? colors.accentSubtle : colors.surfaceField,
        borderRadius: BorderRadius.circular(DropRadius.control),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            DropHaptics.select();
            notes.setCompleted(note.id, completed: !done);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DropTokenSpace.x4,
              vertical: DropTokenSpace.x3,
            ),
            child: Row(
              children: [
                Icon(
                  done ? Icons.check_circle : Icons.circle_outlined,
                  size: DropIconSize.action,
                  color: done ? colors.accent : colors.textMuted,
                ),
                const SizedBox(width: DropTokenSpace.x3),
                Text(
                  done ? '끝낸 할일' : '끝내기',
                  style: DropText.label.copyWith(
                    color: done ? colors.accent : colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 앱바에 서는 동작 하나. 되돌릴 수 없는 것만 위험색이다 — 나머지는
  /// 눌러도 실행 취소 토스트가 받쳐 준다.
  Widget _actionButton(
    BuildContext context,
    NotesController notes,
    Note note,
    NoteViewerAction action,
  ) {
    final colors = DropColors.of(context);
    final isDestructive = action == NoteViewerAction.deletePermanently;
    return IconButton(
      icon: Icon(_icon(action)),
      tooltip: _label(action),
      color: isDestructive ? colors.danger : colors.textPrimary,
      onPressed: () => _perform(context, notes, note, action),
    );
  }

  /// 본문 아래의 부속 — 첨부·태그·댓글. 본문은 페이지 위에 그대로 눕고,
  /// 부속은 **한 장의 묶음 면**에 얹혀 "본문은 여기서 끝났다"를 면이 말한다
  /// (홈 목록의 NoteGroup과 같은 문법, BRU-207 피드백: 구분감).
  Widget _footerGroup(
    BuildContext context,
    Note note,
    CommentsController comments,
    AttachmentUrlProvider urlFor,
  ) {
    final count = comments.countFor(note.id);
    return NoteGroup(
      children: [
        if (note.attachments.isNotEmpty)
          _infoRow(
            context,
            label: '첨부',
            child: Wrap(
              spacing: DropTokenSpace.x2,
              runSpacing: DropTokenSpace.x2,
              children: [
                for (final attachment in note.attachments)
                  GestureDetector(
                    // 볼 수 있는 것만 뷰어로 넘긴다 — 문서는 아이콘으로 남는다.
                    onTap: attachment.isImage || attachment.isVideo
                        ? () => showMediaViewer(
                            context,
                            attachments: note.attachments
                                .where((a) => a.isImage || a.isVideo)
                                .toList(),
                            current: attachment,
                            urlProvider: urlFor,
                          )
                        : null,
                    child: AttachmentThumbnail(
                      attachment: attachment,
                      urlProvider: urlFor,
                    ),
                  ),
              ],
            ),
          ),
        if (note.tags.isNotEmpty)
          _infoRow(
            context,
            label: '태그',
            child: Wrap(
              spacing: DropTokenSpace.x2,
              runSpacing: DropTokenSpace.x2,
              children: [for (final tag in note.tags) _tagPill(context, tag)],
            ),
          ),
        _infoRow(
          context,
          label: '댓글',
          onTap: () =>
              showCommentsSheet(context, note: note, controller: comments),
          child: Builder(
            builder: (context) {
              final colors = DropColors.of(context);
              return Text(
                count > 0 ? '$count개' : '첫 댓글을 남겨 보세요',
                style: DropText.body.copyWith(
                  color: count > 0 ? colors.textPrimary : colors.textTertiary,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 이름표 + 내용 한 줄. 이름표를 왼쪽에 고정 폭으로 세워 세로로 줄이 맞는다 —
  /// 줄마다 이름 길이가 달라 들쭉날쭉하면 훑기가 안 된다.
  Widget _infoRow(
    BuildContext context, {
    required String label,
    required Widget child,
    VoidCallback? onTap,
  }) {
    final colors = DropColors.of(context);
    final row = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: NoteGroup.inset,
        vertical: DropTokenSpace.x4,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                label,
                style: DropText.body.copyWith(color: colors.textTertiary),
              ),
            ),
          ),
          Expanded(child: child),
          if (onTap != null)
            Icon(
              Icons.chevron_right,
              size: DropIconSize.action,
              color: colors.textMuted,
            ),
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }

  Widget _tagPill(BuildContext context, Tag tag) {
    final colors = DropColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DropTokenSpace.x3,
        vertical: DropTokenSpace.x1 + 2,
      ),
      decoration: ShapeDecoration(
        color: colors.surfacePage,
        shape: const StadiumBorder(),
      ),
      child: Text(
        '#${tag.name}',
        style: DropText.meta.copyWith(
          color: colors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Future<void> _perform(
    BuildContext context,
    NotesController notes,
    Note note,
    NoteViewerAction action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    Future<void> Function(String id)? undo;
    String? message;
    switch (action) {
      case NoteViewerAction.archive:
        await notes.archive(note.id);
        undo = notes.unarchive;
        message = '보관했어요';
      case NoteViewerAction.unarchive:
        await notes.unarchive(note.id);
        undo = notes.archive;
        message = '보관을 해제했어요';
      case NoteViewerAction.trash:
        await notes.moveToTrash(note.id);
        undo = notes.restore;
        message = '휴지통으로 옮겼어요';
      case NoteViewerAction.restore:
        await notes.restore(note.id);
        undo = notes.moveToTrash;
        message = '복원했어요';
      case NoteViewerAction.deletePermanently:
        final ok = await showDropConfirmSheet(
          context,
          title: '이 노트를 영구 삭제할까요?',
          message: '휴지통에서도 사라지고 되돌릴 수 없어요.',
          confirmLabel: '삭제',
          isDestructive: true,
        );
        if (!ok) return;
        await notes.deletePermanently(note.id);
        message = '삭제했어요';
      case NoteViewerAction.edit:
      case NoteViewerAction.comments:
        return; // 상태 메뉴에 오지 않는다 — 위에서 걸러졌다.
    }
    DropHaptics.select();
    final id = note.id;
    // 뷰어는 닫고, 알림은 홈 위에 띄운다 — 그래서 메신저를 미리 붙잡아 뒀다.
    if (context.mounted) context.pop();
    showDropToastOn(
      messenger,
      message,
      actionLabel: undo == null ? null : '실행 취소',
      onAction: undo == null ? null : () => undo!(id),
    );
  }

  String _label(NoteViewerAction action) => switch (action) {
    NoteViewerAction.edit => '편집',
    NoteViewerAction.comments => '댓글',
    NoteViewerAction.archive => '보관',
    NoteViewerAction.unarchive => '보관 해제',
    NoteViewerAction.trash => '휴지통으로',
    NoteViewerAction.restore => '복원',
    NoteViewerAction.deletePermanently => '영구 삭제',
  };

  IconData _icon(NoteViewerAction action) => switch (action) {
    NoteViewerAction.edit => Icons.edit_outlined,
    NoteViewerAction.comments => Icons.mode_comment_outlined,
    NoteViewerAction.archive => Icons.archive_outlined,
    NoteViewerAction.unarchive => Icons.unarchive_outlined,
    NoteViewerAction.trash => Icons.delete_outline,
    NoteViewerAction.restore => Icons.restore,
    NoteViewerAction.deletePermanently => Icons.delete_forever_outlined,
  };

  /// 절대 시각 표기 (intl 의존 없이). iOS의 `.abbreviated + .shortened` 대응.
  static String _absoluteTime(DateTime date) {
    final local = date.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.year}. ${local.month}. ${local.day}. $hh:$mm';
  }
}
