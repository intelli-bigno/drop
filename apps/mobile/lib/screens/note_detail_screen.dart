/// 노트를 **펼쳐 읽는** 자리 (BRU-77 · BRU-157). iOS `NoteDetailView.swift` 대응.
///
/// 이 화면은 읽기 전용이다. 여기에는 저장 호출이 없다 — 본문이 서버로 나가는
/// 유일한 길은 "편집"을 눌러 여는 컴포저뿐이다(진짜 컴포저는 BRU-158).
/// 열고 닫는 것만으로는 아무것도 저장되지 않는다 — 데스크톱에서 "펼치기만 해도
/// 원문이 덮어써지던" 사고(BRU-66)의 재발 방지.
///
/// 어떤 동작이 가능한지는 `NoteViewerAction.actionsFor(note)`가 정한다 —
/// 화면이 제 사정으로 버튼을 붙이면 휴지통 노트에 "휴지통으로"가 붙는 식으로 어긋난다.
library;

import 'package:drop_core/drop_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../environment/providers.dart';
import '../notes/notes_controller.dart';
import '../widgets/attachment_thumbnail.dart';
import '../widgets/markdown_view.dart';
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
    // 노트를 통째로 들고 있으면 편집 저장 뒤에도 옛 값이 남는다 —
    // id만 들고 목록에서 매번 찾는다 (BRU-77과 같은 태도).
    final matches = notes.store.allNotes
        .where((note) => note.id == noteId)
        .toList();
    final note = matches.isEmpty ? null : matches.first;

    Future<Uri?> urlFor(Attachment attachment) async {
      try {
        return await container.attachmentsRepository
            .signedUrl(attachment.storagePath);
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
        actions: [
          // 편집은 여기 하나뿐이다. 뷰어 어디를 눌러도 편집기가 열리지 않는다.
          if (actions.contains(NoteViewerAction.edit))
            TextButton(
              onPressed: note == null
                  ? null
                  : () => showComposerSheet(context, notes,
                      target: ComposerTarget.existing(note)),
              child: const Text('편집'),
            ),
          if (note != null) _stateMenu(context, notes, note, actions),
        ],
      ),
      body: note == null
          ? const Center(child: Text('노트를 찾을 수 없습니다'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(context, note),
                  const SizedBox(height: 16),
                  _content(context, note),
                  if (note.attachments.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _attachments(context, note, urlFor),
                  ],
                  if (note.tags.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _tags(context, note),
                  ],
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () => showCommentsSheet(
                        context,
                        note: note,
                        controller: comments,
                      ),
                      icon: const Icon(Icons.mode_comment_outlined, size: 18),
                      label: Text(
                        comments.countFor(note.id) > 0
                            ? '댓글 ${comments.countFor(note.id)}개'
                            : '댓글',
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // 조각

  /// 시각. 고친 적이 있으면 그것도 보여 준다 — 뷰어만 열었을 때 이 값이
  /// 움직이지 않는다는 것이 이 화면의 계약이다 (BRU-77 완료 기준).
  Widget _header(BuildContext context, Note note) {
    final theme = Theme.of(context);
    return Row(
      children: [
        if (note.isPinned)
          const Padding(
            padding: EdgeInsets.only(right: 6),
            child: Icon(Icons.push_pin, size: 14),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_absoluteTime(note.createdAt), style: theme.textTheme.bodySmall),
              if (note.updatedAt.difference(note.createdAt).inSeconds > 1)
                Text(
                  '수정 ${relativeTimeString(note.updatedAt, now: DateTime.now())}',
                  style: theme.textTheme.labelSmall,
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// 본문 전문 — 마크다운을 drop_core 파서 결과 그대로 그린다.
  /// 렌더러는 그리기만 하고 아무것도 되돌려 쓰지 않는다.
  Widget _content(BuildContext context, Note note) {
    if (note.content.isEmpty) {
      return Text('빈 노트', style: Theme.of(context).textTheme.bodyMedium);
    }
    return SelectionArea(child: MarkdownView(source: note.content));
  }

  Widget _attachments(
    BuildContext context,
    Note note,
    AttachmentUrlProvider urlFor,
  ) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final attachment in note.attachments)
            GestureDetector(
              // 볼 수 있는 것만 뷰어로 넘긴다 — 문서는 썸네일 자리에 아이콘으로 남는다.
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
      );

  Widget _tags(BuildContext context, Note note) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      children: [
        for (final tag in note.tags)
          Text('#${tag.name}', style: theme.textTheme.bodySmall),
      ],
    );
  }

  /// 보관·휴지통 같은 상태 변경 — 본문은 건드리지 않는다.
  Widget _stateMenu(
    BuildContext context,
    NotesController notes,
    Note note,
    List<NoteViewerAction> actions,
  ) {
    final stateActions = actions
        .where(
          (action) =>
              action != NoteViewerAction.edit &&
              action != NoteViewerAction.comments,
        )
        .toList();
    return PopupMenuButton<NoteViewerAction>(
      icon: const Icon(Icons.more_horiz),
      tooltip: '더보기',
      onSelected: (action) => _perform(context, notes, note, action),
      itemBuilder: (context) => [
        for (final action in stateActions)
          PopupMenuItem(
            value: action,
            child: ListTile(
              leading: Icon(_icon(action)),
              title: Text(_label(action)),
              textColor: action == NoteViewerAction.deletePermanently
                  ? Theme.of(context).colorScheme.error
                  : null,
              iconColor: action == NoteViewerAction.deletePermanently
                  ? Theme.of(context).colorScheme.error
                  : null,
              contentPadding: EdgeInsets.zero,
            ),
          ),
      ],
    );
  }

  /// 상태를 바꿨으면 이 노트는 지금 보고 있는 목록에서 사라진다 — 뷰어도 닫는다
  /// (iOS `perform(_:)`와 같은 규칙).
  Future<void> _perform(
    BuildContext context,
    NotesController notes,
    Note note,
    NoteViewerAction action,
  ) async {
    switch (action) {
      case NoteViewerAction.archive:
        await notes.archive(note.id);
      case NoteViewerAction.unarchive:
        await notes.unarchive(note.id);
      case NoteViewerAction.trash:
        await notes.moveToTrash(note.id);
      case NoteViewerAction.restore:
        await notes.restore(note.id);
      case NoteViewerAction.deletePermanently:
        await notes.deletePermanently(note.id);
      case NoteViewerAction.edit:
      case NoteViewerAction.comments:
        return; // 상태 메뉴에 오지 않는다 — 위에서 걸러졌다.
    }
    if (context.mounted) context.pop();
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
