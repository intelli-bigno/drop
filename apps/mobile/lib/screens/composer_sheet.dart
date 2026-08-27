/// 노트 컴포저 — iOS `NoteComposerSheet.swift` 대응 (BRU-158).
/// DROP의 핵심 동선 — 빠르게 던져넣기.
///
/// 본문은 평문 마크다운이다. 여기서 쓰고(툴바), 여기서 읽는다(미리보기) —
/// 목록은 한 줄만 보여 주므로 노트를 다 읽는 자리도 결국 이 시트다 (BRU-37, BRU-49).
library;

import 'package:drop_core/drop_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../environment/providers.dart';
import '../notes/notes_controller.dart';
import '../widgets/markdown_toolbar.dart';

/// 어느 노트를 쓰는 중인가. iOS `ComposerTarget`(HomeView.swift) 대응.
sealed class ComposerTarget {
  const ComposerTarget();

  const factory ComposerTarget.newNote() = NewNoteTarget;

  /// 딥링크로 들어온 초안 — 본문이 미리 채워진 채로 열린다.
  const factory ComposerTarget.newWithText(String text) = NewNoteWithTextTarget;

  const factory ComposerTarget.existing(Note note) = ExistingNoteTarget;

  /// 어느 노트에 딸린 새 노트를 쓴다 (BRU-69).
  const factory ComposerTarget.reply(Note parent) = ReplyTarget;

  /// 이미 있는 노트를 고치는 중이면 그 id. 새 노트·답글은 null — 만들고 나서 붙인다.
  String? get editingNoteId => switch (this) {
        ExistingNoteTarget(:final note) => note.id,
        _ => null,
      };

  bool get isNew => editingNoteId == null;

  String get seedText => switch (this) {
        ExistingNoteTarget(:final note) => note.content,
        NewNoteWithTextTarget(:final text) => text,
        _ => '',
      };

  /// 어느 노트에 딸리는 글인지 제목으로 알려 준다 — 답글 시트는 새 노트 시트와
  /// 생김새가 같아서, 표시가 없으면 무엇을 쓰는 중인지 알 수 없다 (BRU-69).
  String get title => switch (this) {
        ExistingNoteTarget() => '노트 편집',
        ReplyTarget(:final parent) =>
          '답글 — ${parent.displayId > 0 ? '#${parent.displayId}' : '노트'}',
        NewNoteTarget() || NewNoteWithTextTarget() => '새 노트',
      };
}

class NewNoteTarget extends ComposerTarget {
  const NewNoteTarget();
}

class NewNoteWithTextTarget extends ComposerTarget {
  final String text;

  const NewNoteWithTextTarget(this.text);
}

class ExistingNoteTarget extends ComposerTarget {
  final Note note;

  const ExistingNoteTarget(this.note);
}

class ReplyTarget extends ComposerTarget {
  final Note parent;

  const ReplyTarget(this.parent);
}

/// 사진·영상을 고르는 손. 테스트가 실제 선택기 대신 표본을 밀어 넣는 자리다.
typedef ComposerMediaPicker = Future<List<PendingAttachment>> Function();

/// 컴포저를 연다. 홈 FAB은 기본값(새 노트)으로, 뷰어는 편집·답글 타깃으로 부른다.
Future<void> showComposerSheet(
  BuildContext context,
  NotesController controller, {
  ComposerTarget target = const ComposerTarget.newNote(),
  ComposerMediaPicker? pickMedia,
}) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => FractionallySizedBox(
        // iOS presentationDetents([.medium, .large])의 근사 — 키보드가 올라오는
        // 시트라 처음부터 크게 연다.
        heightFactor: 0.92,
        child: ComposerSheet(
          controller: controller,
          target: target,
          pickMedia: pickMedia,
        ),
      ),
    );

class ComposerSheet extends ConsumerStatefulWidget {
  final NotesController controller;
  final ComposerTarget target;
  final ComposerMediaPicker? pickMedia;

  const ComposerSheet({
    super.key,
    required this.controller,
    required this.target,
    this.pickMedia,
  });

  @override
  ConsumerState<ComposerSheet> createState() => _ComposerSheetState();
}

class _ComposerSheetState extends ConsumerState<ComposerSheet> {
  late final TextEditingController _text =
      TextEditingController(text: widget.target.seedText);

  bool _isPreviewing = false;

  /// 저장 중 중복 탭을 막지 않으면 노트가 두 번 만들어진다.
  bool _isSaving = false;

  /// 노트 id가 생기기 전에 고른 파일. 제출 때 함께 넘긴다 (BRU-131).
  final List<PendingAttachment> _pending = [];

  @override
  void initState() {
    super.initState();
    // canSubmit이 본문을 본다 — 글자가 바뀔 때마다 버튼 상태를 다시 판정한다.
    _text.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _text.removeListener(_onTextChanged);
    _text.dispose();
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  /// 본문이 비어도 고른 파일이 있으면 제출할 수 있다 (BRU-131).
  bool get _canSubmit => _text.text.trim().isNotEmpty || _pending.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 하단 액션 줄이 키보드 위에 서도록 (BRU-132).
      padding:
          EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              widget.target.title,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: _editorOrPreview()),
          // 툴바는 키보드 위에 붙는다. 미리보기 중에는 칠 것이 없으니 걷는다.
          if (!_isPreviewing) MarkdownToolbar(onCommand: _apply),
          const Divider(height: 1),
          _composerActions(),
        ],
      ),
    );
  }

  Widget _editorOrPreview() {
    if (_isPreviewing) {
      return _MarkdownPreview(source: _text.text);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      // 시트가 뜨자마자 키보드가 올라와야 "던져넣기"가 끊기지 않는다.
      child: TextField(
        controller: _text,
        autofocus: true,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        keyboardType: TextInputType.multiline,
        decoration: const InputDecoration(
          hintText: '무엇이든 적어 두세요',
          border: InputBorder.none,
        ),
      ),
    );
  }

  /// 닫기 / 미리보기 / 사진 / 추가(저장). 키보드 바로 위, 마크다운 툴바 옆 (BRU-132).
  Widget _composerActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          TextButton(
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
            child: const Text('닫기'),
          ),
          // 편집↔미리보기 전환.
          //
          // **미리보기는 읽기만 한다.** 이 버튼은 화면 상태(`_isPreviewing`)만
          // 바꾸고 본문도 저장 경로도 건드리지 않는다 — 열람했더니 본문이
          // 달라져 있는 일이 다시 생기면 안 된다 (BRU-66).
          IconButton(
            tooltip: '미리보기 전환',
            icon: Icon(_isPreviewing
                ? Icons.edit_outlined
                : Icons.visibility_outlined),
            onPressed: _isSaving
                ? null
                : () => setState(() => _isPreviewing = !_isPreviewing),
          ),
          IconButton(
            tooltip: '사진 첨부',
            icon: const Icon(Icons.photo_library_outlined),
            onPressed: _isSaving ? null : _pickMedia,
          ),
          if (_pending.isNotEmpty)
            Text(
              '첨부 ${_pending.length}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const Spacer(),
          FilledButton(
            onPressed: (_isSaving || !_canSubmit) ? null : _submit,
            child: Text(widget.target.isNew ? '추가' : '저장'),
          ),
        ],
      ),
    );
  }

  /// 툴바 명령을 본문에 적용한다. 무엇을 어디에 끼워 넣을지는 전부 drop_core의
  /// `MarkdownEditor`가 정한다 — 화면은 결과만 받아 든다.
  ///
  /// `TextEditingController.selection`은 UTF-16 코드유닛 단위 — `EditorRange`와
  /// 같은 계약이라 값이 그대로 오간다.
  void _apply(MarkdownEditingCommand command) {
    final value = _text.value;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    final result = MarkdownEditor.apply(
      command,
      value.text,
      EditorRange(selection.start, selection.end - selection.start),
    );
    _text.value = TextEditingValue(
      text: result.text,
      selection: TextSelection(
        baseOffset: result.selection.location,
        extentOffset: result.selection.end,
      ),
    );
  }

  Future<void> _pickMedia() async {
    final picker = widget.pickMedia ?? _pickWithImagePicker;
    final picked = await picker();
    if (picked.isEmpty || !mounted) return;
    setState(() => _pending.addAll(picked));
  }

  /// 실제 선택기. iOS PhotosPicker(최대 5개, 사진·영상)와 같은 조건.
  static Future<List<PendingAttachment>> _pickWithImagePicker() async {
    final files = await ImagePicker().pickMultipleMedia(limit: 5);
    return [
      for (final file in files)
        PendingAttachment(
          data: await file.readAsBytes(),
          fileName: file.name,
          type: AttachmentType.forFileName(file.name),
        ),
    ];
  }

  /// 본문과 대기 첨부를 저장한다. 첨부는 노트 id가 생긴 뒤에만 올린다 (BRU-131) —
  /// 기존 노트는 그 id에 붙이고(새 display_id 금지), 새 노트·답글은 만들고 붙인다.
  /// iOS `HomeView.submitComposer` 대응.
  Future<void> _submit() async {
    if (_isSaving || !_canSubmit) return;
    setState(() => _isSaving = true);

    final controller = widget.controller;
    final content = _text.text.trim();
    final destination = ComposerAttachmentRouting.destination(
      editingNoteId: widget.target.editingNoteId,
    );

    String? createdId;
    switch (widget.target) {
      case NewNoteTarget() || NewNoteWithTextTarget():
        createdId = (await controller.create(content: content))?.id;
      case ExistingNoteTarget(:final note):
        await controller.update(id: note.id, content: content);
      case ReplyTarget(:final parent):
        createdId =
            (await controller.create(content: content, parentId: parent.id))
                ?.id;
    }

    final noteId = ComposerAttachmentRouting.noteIdToAttach(
      destination: destination,
      createdNoteId: createdId,
    );
    if (_pending.isNotEmpty && noteId != null) {
      final repository = ref.read(dropContainerProvider).attachmentsRepository;
      for (final item in _pending) {
        try {
          await repository.upload(
            data: item.data,
            fileName: item.fileName,
            type: item.type,
            noteId: noteId,
          );
        } catch (error) {
          // 업로드 실패는 목록의 오류 배너와 같은 자리로 흐른다.
          controller.store.report(error);
        }
      }
      await controller.load();
    }

    if (mounted) Navigator.of(context).pop();
  }
}

/// 미리보기 렌더 — drop_core 파서의 읽기 전용 표현을 그대로 그린다.
///
/// 컴포저 전용으로 이 파일에 둔다. 뷰어(BRU-157)의 렌더와 한 몸이 되는 정리는
/// 두 트랙이 합류한 뒤의 일이다.
class _MarkdownPreview extends StatelessWidget {
  final String source;

  const _MarkdownPreview({required this.source});

  @override
  Widget build(BuildContext context) {
    final document = const MarkdownParser().parse(source);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        for (final block in document.blocks) ...[
          _block(context, block),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _block(BuildContext context, MarkdownBlock block) {
    final theme = Theme.of(context);
    switch (block) {
      case MarkdownHeading(:final level, :final content):
        final style = switch (level) {
          1 => theme.textTheme.headlineSmall,
          2 => theme.textTheme.titleLarge,
          3 => theme.textTheme.titleMedium,
          _ => theme.textTheme.titleSmall,
        };
        return Text.rich(
          _inlineSpan(context, content),
          style: style?.copyWith(fontWeight: FontWeight.w700),
        );

      case MarkdownParagraph(:final content):
        return Text.rich(
          _inlineSpan(context, content),
          style: theme.textTheme.bodyMedium,
        );

      case MarkdownList(:final items):
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in items)
              Padding(
                padding: EdgeInsets.only(left: item.indent * 16.0, bottom: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 24, child: _listMarker(context, item)),
                    Expanded(
                      child: Text.rich(
                        _inlineSpan(context, item.content),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );

      case MarkdownCodeBlock(:final code):
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            code,
            style: theme.textTheme.bodySmall
                ?.copyWith(fontFamily: 'monospace'),
          ),
        );

      case MarkdownQuote(:final blocks):
        return Container(
          padding: const EdgeInsets.only(left: 12),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: theme.colorScheme.outline, width: 3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final inner in blocks) _block(context, inner),
            ],
          ),
        );

      case MarkdownThematicBreak():
        return const Divider();
    }
  }

  Widget _listMarker(BuildContext context, MarkdownListItem item) {
    final checked = item.checked;
    if (checked != null) {
      return Icon(
        checked ? Icons.check_box_outlined : Icons.check_box_outline_blank,
        size: 18,
      );
    }
    final ordinal = item.ordinal;
    return Text(
      ordinal != null ? '$ordinal.' : '•',
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }

  TextSpan _inlineSpan(BuildContext context, List<MarkdownInline> content) =>
      TextSpan(
        children: [for (final inline in content) _span(context, inline)],
      );

  TextSpan _span(BuildContext context, MarkdownInline inline) {
    final theme = Theme.of(context);
    switch (inline) {
      case MarkdownText(:final value):
        return TextSpan(text: value);
      case MarkdownStrong(:final content):
        return TextSpan(
          children: [for (final inner in content) _span(context, inner)],
          style: const TextStyle(fontWeight: FontWeight.w700),
        );
      case MarkdownEmphasis(:final content):
        return TextSpan(
          children: [for (final inner in content) _span(context, inner)],
          style: const TextStyle(fontStyle: FontStyle.italic),
        );
      case MarkdownCode(:final value):
        return TextSpan(
          text: value,
          style: TextStyle(
            fontFamily: 'monospace',
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        );
      case MarkdownLink(:final content):
        // 읽기 전용 미리보기 — 링크는 열지 않고 생김새만 보여 준다.
        return TextSpan(
          children: [for (final inner in content) _span(context, inner)],
          style: TextStyle(
            color: theme.colorScheme.primary,
            decoration: TextDecoration.underline,
          ),
        );
    }
  }
}
