/// Components — 실물 위젯 (BRU-193). 데스크톱 `styleguide/sections/Components.tsx` 대응.
///
/// 여기 진열되는 것은 **앱이 실제로 쓰는 위젯**이다. 쇼케이스 전용으로 다시 만든
/// 복제품이 아니다 — 복제하는 순간 쇼케이스에서만 예쁜 컴포넌트가 태어나고,
/// 진짜 화면은 그대로 남는다.
library;

import 'package:drop_core/drop_core.dart';
import 'package:flutter/material.dart';

import '../../notes/notes_controller.dart';
import '../../theme/drop_theme.dart';
import '../../widgets/attachment_thumbnail.dart';
import '../../widgets/markdown_toolbar.dart';
import '../../widgets/markdown_view.dart';
import '../../widgets/note_card.dart';
import '../../widgets/note_filter_bar.dart';
import '../../widgets/selection_action_bar.dart';
import '../fixtures.dart';
import '../parts.dart';

class ComponentsSection extends StatefulWidget {
  const ComponentsSection({super.key});

  @override
  State<ComponentsSection> createState() => _ComponentsSectionState();
}

class _ComponentsSectionState extends State<ComponentsSection> {
  /// 필터 줄·선택 줄은 컨트롤러를 요구한다. 인메모리 리포지토리로 세운다 —
  /// Supabase도 로그인도 타지 않아야 브라우저에서 그냥 뜬다.
  late final NotesController _controller = NotesController(
    NotesStore(
      repository: InMemoryNotesRepository(
        notes: showcaseRows.map((row) => row.note).toList(),
      ),
    ),
  );

  /// 선택 줄을 보여 주려면 선택된 노트가 있어야 한다.
  late final NotesController _selectingController = NotesController(
    NotesStore(
      repository: InMemoryNotesRepository(
        notes: showcaseRows.map((row) => row.note).toList(),
      ),
    ),
  );

  @override
  void initState() {
    super.initState();
    _controller.load();
    _selectingController.load().then((_) {
      if (!mounted) return;
      _selectingController.toggleSelection(noteShort.id);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _selectingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(DropTokenSpace.x5),
      children: [
        const PageHead(
          title: 'Components',
          lede:
              '앱이 실제로 쓰는 위젯을 그대로 세워 둔 것이다. 폰 너비(390)로 가둬 '
              '브라우저 전폭에 늘어나지 않게 했다.',
        ),
        Specimen(
          name: 'NoteCard',
          desc: '목록의 한 줄 — 고정·할일·답글·첨부',
          file: 'lib/widgets/note_card.dart',
          phone: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final row in showcaseRows)
                NoteCard(
                  row: row,
                  isSelecting: false,
                  isSelected: false,
                  commentCount: row.note.id == noteLong.id ? 3 : 0,
                  onTap: () {},
                  onDoubleTap: () {},
                  onLongPress: () {},
                  onToggleCompleted: () {},
                ),
            ],
          ),
        ),
        Specimen(
          name: 'NoteCard — 선택 모드',
          desc: '체크 동그라미가 앞에 서고 할일 체크박스는 물러난다',
          file: 'lib/widgets/note_card.dart',
          phone: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NoteCard(
                row: NoteRow(note: notePinned, depth: 0),
                isSelecting: true,
                isSelected: true,
                commentCount: 0,
                onTap: () {},
                onDoubleTap: () {},
                onLongPress: () {},
              ),
              NoteCard(
                row: NoteRow(note: todoOpen, depth: 0),
                isSelecting: true,
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
          name: 'NoteFilterBar',
          desc: '검색 · 카테고리 · 필터 세 줄 (BRU-207, BRU-49의 한 줄 원칙을 접음)',
          file: 'lib/widgets/note_filter_bar.dart',
          phone: true,
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => NoteFilterBar(controller: _controller),
          ),
        ),
        Specimen(
          name: 'SelectionActionBar',
          desc: '보고 있는 뷰 모드에 따라 할 수 있는 일이 달라진다',
          file: 'lib/widgets/selection_action_bar.dart',
          phone: true,
          child: ListenableBuilder(
            listenable: _selectingController,
            builder: (context, _) =>
                SelectionActionBar(controller: _selectingController),
          ),
        ),
        Specimen(
          name: 'MarkdownToolbar',
          desc: '컴포저의 마크다운 입력 보조 (BRU-37)',
          file: 'lib/widgets/markdown_toolbar.dart',
          phone: true,
          child: MarkdownToolbar(onCommand: (_) {}),
        ),
        Specimen(
          name: 'MarkdownView',
          desc: '뷰어의 본문 — 기호가 아니라 위젯으로 그린다',
          file: 'lib/widgets/markdown_view.dart',
          phone: true,
          child: const MarkdownView(source: _markdownSample),
        ),
        Specimen(
          name: 'AttachmentThumbnail',
          desc: '서명 URL을 못 받으면 종류 아이콘으로 남는다 — 쇼케이스는 항상 그 상태다',
          file: 'lib/widgets/attachment_thumbnail.dart',
          child: Wrap(
            spacing: DropTokenSpace.x2,
            children: [
              for (final type in [
                AttachmentType.image,
                AttachmentType.video,
                AttachmentType.audio,
                AttachmentType.file,
              ])
                AttachmentThumbnail(
                  attachment: Attachment(
                    id: 'showcase-$type',
                    noteId: noteWithAttachments.id,
                    type: type,
                    storagePath: 'showcase/$type',
                    createdAt: showcaseNow,
                  ),
                  urlProvider: (_) async => null,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

const _markdownSample =
    '## 마크다운 제목\n\n'
    '**굵게**와 *기울임*, 그리고 `인라인 코드`가 섞인 본문.\n\n'
    '- 목록 첫째\n'
    '- 목록 둘째\n\n'
    '> 인용문\n\n'
    '```\n코드 블록\n```';
