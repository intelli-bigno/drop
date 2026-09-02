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
import '../theme/drop_theme.dart';
import '../widgets/drop_action_sheet.dart';
import '../widgets/drop_feedback.dart';
import '../widgets/markdown_toolbar.dart';
import '../widgets/markdown_view.dart';

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
  // 닫는 길은 X 하나다 — 스크림 탭·끌어내리기로 쓰던 글이 조용히 사라지면 안 된다.
  // (닫기 전 버릴지 묻는 것은 ComposerSheet의 PopScope가 한다.)
  isDismissible: false,
  enableDrag: false,
  showDragHandle: false,
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
  late final TextEditingController _text = TextEditingController(
    text: widget.target.seedText,
  );

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

  /// 열었을 때와 달라진 것이 있나 — 있으면 닫기 전에 묻는다.
  bool get _isDirty =>
      _text.text.trim() != widget.target.seedText.trim() || _pending.isNotEmpty;

  /// 닫기. 쓰던 것이 있으면 버릴지 먼저 묻는다 — 저장 중에는 닫지 않는다.
  Future<void> _close() async {
    if (_isSaving) return;
    if (_isDirty) {
      final discard = await showDropConfirmSheet(
        context,
        title: '쓰던 내용을 버릴까요?',
        message: '저장하지 않은 글과 첨부가 사라져요.',
        confirmLabel: '버리기',
        cancelLabel: '계속 쓰기',
        isDestructive: true,
      );
      if (!discard || !mounted) return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // 뒤로 가기(안드로이드·키보드 Esc)도 X와 같은 길을 탄다.
      canPop: !_isDirty && !_isSaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Padding(
        // 하단 액션 줄이 키보드 위에 서도록 (BRU-132).
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: DropTokenSpace.x3),
            DropSheetHeader(title: widget.target.title, onClose: _close),
            Expanded(
              // 편집↔미리보기는 녹아들며 바뀐다.
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: KeyedSubtree(
                  key: ValueKey(_isPreviewing),
                  child: _editorOrPreview(),
                ),
              ),
            ),
            if (_pending.isNotEmpty) _pendingStrip(),
            // 툴바는 키보드 위에 붙는다. 미리보기 중에는 칠 것이 없으니 걷는다.
            AnimatedSize(
              duration: const Duration(milliseconds: 160),
              alignment: Alignment.bottomCenter,
              child: _isPreviewing
                  ? const SizedBox(width: double.infinity)
                  : MarkdownToolbar(
                      onCommand: (command) {
                        DropHaptics.select();
                        _apply(command);
                      },
                    ),
            ),
            const Divider(height: 1),
            _composerActions(),
          ],
        ),
      ),
    );
  }

  /// 고른 첨부의 미리보기 줄. 숫자("첨부 1")만으로는 무엇을 골랐는지 모른다 —
  /// 썸네일로 보여 주고, 잘못 고른 것은 그 자리에서 뺀다.
  Widget _pendingStrip() {
    final colors = DropColors.of(context);
    const size = 64.0;
    return SizedBox(
      height: size + DropTokenSpace.x3,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
          DropLayout.gutter,
          0,
          DropLayout.gutter,
          DropTokenSpace.x3,
        ),
        children: [
          for (final item in _pending)
            Padding(
              padding: const EdgeInsets.only(right: DropTokenSpace.x2),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(DropRadius.thumbnail),
                    child: Container(
                      width: size,
                      height: size,
                      color: colors.surfaceField,
                      child: item.type == AttachmentType.image
                          ? Image.memory(
                              item.data,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                              errorBuilder: (context, error, stack) => Icon(
                                Icons.image_outlined,
                                color: colors.textMuted,
                              ),
                            )
                          : Icon(
                              item.type == AttachmentType.video
                                  ? Icons.videocam_outlined
                                  : Icons.description_outlined,
                              color: colors.textMuted,
                            ),
                    ),
                  ),
                  Positioned(
                    top: -DropTokenSpace.x1,
                    right: -DropTokenSpace.x1,
                    child: Tooltip(
                      message: '첨부 빼기',
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _isSaving
                            ? null
                            : () {
                                DropHaptics.select();
                                setState(() => _pending.remove(item));
                              },
                        child: Container(
                          width: DropIconSize.control,
                          height: DropIconSize.control,
                          decoration: ShapeDecoration(
                            color: colors.surfaceInverse,
                            shape: const CircleBorder(),
                          ),
                          child: Icon(
                            Icons.close,
                            size: DropIconSize.meta,
                            color: colors.onInverse,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _editorOrPreview() {
    final colors = DropColors.of(context);
    if (_isPreviewing) {
      // 뷰어와 같은 렌더러 — 쓰면서 본 것과 저장 뒤 읽는 것이 같아야 한다.
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: DropLayout.gutter,
          vertical: DropTokenSpace.x2,
        ),
        child: MarkdownView(source: _text.text),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DropLayout.gutter),
      // 시트가 뜨자마자 키보드가 올라와야 "던져넣기"가 끊기지 않는다.
      child: TextField(
        controller: _text,
        autofocus: true,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        keyboardType: TextInputType.multiline,
        style: DropText.reading.copyWith(color: colors.textPrimary),
        decoration: const InputDecoration(hintText: '무엇이든 적어 두세요'),
      ),
    );
  }

  /// 미리보기 / 사진 / 추가(저장). 키보드 바로 위, 마크다운 툴바 옆 (BRU-132).
  /// 닫기는 시트 머리(오른쪽 X)로 올라갔다 — 저장과 같은 줄에 두면 손이 헷갈린다.
  Widget _composerActions() {
    final colors = DropColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DropTokenSpace.x2,
        DropTokenSpace.x2,
        DropLayout.gutter,
        DropTokenSpace.x2,
      ),
      child: Row(
        children: [
          // 편집↔미리보기 전환.
          //
          // **미리보기는 읽기만 한다.** 이 버튼은 화면 상태(`_isPreviewing`)만
          // 바꾸고 본문도 저장 경로도 건드리지 않는다 — 열람했더니 본문이
          // 달라져 있는 일이 다시 생기면 안 된다 (BRU-66).
          IconButton(
            tooltip: '미리보기 전환',
            isSelected: _isPreviewing,
            icon: const Icon(Icons.visibility_outlined),
            selectedIcon: const Icon(Icons.edit_outlined),
            onPressed: _isSaving
                ? null
                : () {
                    DropHaptics.select();
                    setState(() => _isPreviewing = !_isPreviewing);
                  },
          ),
          IconButton(
            tooltip: '사진 첨부',
            icon: const Icon(Icons.photo_library_outlined),
            onPressed: _isSaving ? null : _pickMedia,
          ),
          if (_pending.isNotEmpty)
            Text(
              '첨부 ${_pending.length}',
              style: DropText.meta.copyWith(color: colors.textSecondary),
            ),
          const Spacer(),
          FilledButton(
            onPressed: (_isSaving || !_canSubmit) ? null : _submit,
            child: _isSaving
                // 저장 중임을 버튼 자체가 말한다 — 비활성만으로는 "고장났나"가 된다.
                ? SizedBox(
                    width: DropTokenSpace.x4,
                    height: DropTokenSpace.x4,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.textMuted,
                    ),
                  )
                : Text(widget.target.isNew ? '추가' : '저장'),
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
        createdId = (await controller.create(
          content: content,
          parentId: parent.id,
        ))?.id;
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

    DropHaptics.select();
    if (mounted) Navigator.of(context).pop();
  }
}
