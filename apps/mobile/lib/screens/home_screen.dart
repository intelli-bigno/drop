/// 홈 피드 — 앱 사용 시간의 대부분이 여기다. iOS `HomeView.swift` 대응 (BRU-156).
///
/// 날짜 묶기·계층 들여쓰기·필터·정렬은 전부 drop_core의 순수 로직이 정하고,
/// 이 화면은 그 결과(`NoteSection` → `NoteRow`)를 그대로 그리기만 한다.
/// 스타일은 Material 기본값 — 토큰 테마는 BRU-159가 얹는다.
library;

import 'package:drop_core/drop_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../environment/providers.dart';
import '../notes/comments_controller.dart';
import '../notes/note_tap.dart';
import '../notes/notes_controller.dart';
import '../widgets/note_card.dart';
import '../widgets/note_filter_bar.dart';
import '../widgets/selection_action_bar.dart';
import 'composer_sheet.dart';

class HomeScreen extends ConsumerWidget {
  /// 날짜 섹션 묶기는 drop_core의 순수 함수가 한다 — 자정·시간대 경계를
  /// 화면 코드에 두면 검증할 방법이 없다.
  static const _grouper = NoteDateGrouper();

  /// 목록 상태의 스코프 키. 사용자가 바뀌면 목록도 처음부터 다시 만든다.
  final String? userId;

  const HomeScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final container = ref.watch(dropContainerProvider);
    final notes = ref.watch(notesControllerProvider(userId));
    final comments = ref.watch(commentsControllerProvider(userId));
    final store = notes.store;

    return Scaffold(
      appBar: AppBar(
        // 보기 전환이 ⋯ 메뉴로 들어가 화면에 안 보이므로, 지금 어디를 보고
        // 있는지는 제목이 알려 준다.
        title: Text(_title(store)),
        leading: store.isSelecting
            ? TextButton(
                onPressed: notes.clearSelection,
                child: const Text('취소'),
              )
            : null,
        leadingWidth: store.isSelecting ? 72 : null,
        actions: [
          if (!store.isSelecting) _menu(ref, notes, container.isPreview),
        ],
      ),
      body: Column(
        children: [
          NoteFilterBar(controller: notes),
          if (store.errorMessage != null)
            MaterialBanner(
              content: Text(store.errorMessage!),
              actions: [
                TextButton(
                  onPressed: notes.dismissError,
                  child: const Text('확인'),
                ),
              ],
            ),
          Expanded(
            // 화면 진입과 당겨서 새로고침이 같은 입구(store.load)를 쓴다.
            child: RefreshIndicator(
              onRefresh: notes.load,
              child: _feed(context, notes, comments),
            ),
          ),
        ],
      ),
      floatingActionButton: store.isSelecting
          ? null
          : FloatingActionButton(
              tooltip: '새 노트',
              // 편집·답글 타깃은 뷰어(BRU-157)가 같은 입구로 연다.
              onPressed: () => showComposerSheet(context, notes),
              child: const Icon(Icons.add),
            ),
      bottomNavigationBar: store.isSelecting
          ? SelectionActionBar(controller: notes)
          : null,
    );
  }

  String _title(NotesStore store) {
    if (store.isSelecting) return '${store.selectedIds.length}개 선택됨';
    return switch (store.viewMode) {
      NoteViewMode.active => 'DROP',
      NoteViewMode.archived => '보관',
      NoteViewMode.trash => '휴지통',
    };
  }

  Widget _menu(WidgetRef ref, NotesController notes, bool isPreview) {
    final store = notes.store;
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz),
      tooltip: '더보기',
      onSelected: (value) {
        switch (value) {
          case 'active':
            notes.setViewMode(NoteViewMode.active);
          case 'archived':
            notes.setViewMode(NoteViewMode.archived);
          case 'trash':
            notes.setViewMode(NoteViewMode.trash);
          case 'signOut':
            ref.read(authControllerProvider).signOut();
        }
      },
      itemBuilder: (context) => [
        _viewModeItem(
          'active',
          '노트',
          Icons.inbox_outlined,
          isOn: store.viewMode == NoteViewMode.active,
        ),
        _viewModeItem(
          'archived',
          '보관',
          Icons.archive_outlined,
          isOn: store.viewMode == NoteViewMode.archived,
        ),
        _viewModeItem(
          'trash',
          '휴지통',
          Icons.delete_outline,
          isOn: store.viewMode == NoteViewMode.trash,
        ),
        if (!isPreview) ...[
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'signOut',
            child: ListTile(
              leading: Icon(Icons.logout),
              title: Text('로그아웃'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ],
    );
  }

  PopupMenuItem<String> _viewModeItem(
    String value,
    String label,
    IconData icon, {
    required bool isOn,
  }) => PopupMenuItem(
    value: value,
    child: ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: isOn ? const Icon(Icons.check, size: 18) : null,
      contentPadding: EdgeInsets.zero,
    ),
  );

  /// **스크롤 컨테이너는 항상 하나, 항상 여기 있다** (iOS PR #40의 교훈).
  /// 로딩·빈 상태에서 스크롤 컨테이너가 없는 뷰로 갈라지면 RefreshIndicator가
  /// 당길 대상을 잃는다 — 갈림길은 컨테이너 **안쪽**에 둔다.
  Widget _feed(
    BuildContext context,
    NotesController notes,
    CommentsController comments,
  ) {
    final store = notes.store;
    final rows = store.visibleRows;

    if (store.isLoading && rows.isEmpty) {
      return _fillViewport(context, const CircularProgressIndicator());
    }
    if (rows.isEmpty) {
      return _fillViewport(context, _emptyState(context, store));
    }

    final sections = _grouper.sections(rows);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        for (final section in sections) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              section.title,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          for (final row in section.rows)
            NoteCard(
              key: ValueKey('note-${row.id}'),
              row: row,
              isSelecting: store.isSelecting,
              isSelected: store.selectedIds.contains(row.id),
              commentCount: comments.countFor(row.id),
              onTap: () => _handleTap(context, notes, row.note, count: 1),
              onDoubleTap: () => _handleTap(context, notes, row.note, count: 2),
              // 롱프레스는 선택 모드 하나만 쓴다.
              onLongPress: () => notes.toggleSelection(row.id),
            ),
        ],
      ],
    );
  }

  /// 싱글탭은 뷰어(BRU-77), 더블탭은 본문 복사(BRU-129).
  /// 선택 모드에서는 둘 다 토글만 — 판정은 순수 함수가 한다.
  void _handleTap(
    BuildContext context,
    NotesController notes,
    Note note, {
    required int count,
  }) {
    switch (resolveNoteTap(
      isSelecting: notes.store.isSelecting,
      count: count,
    )) {
      case NoteTapResult.toggleSelection:
        notes.toggleSelection(note.id);
      case NoteTapResult.copyContent:
        Clipboard.setData(
          ClipboardData(text: NoteCopying.clipboardString(note)),
        );
      case NoteTapResult.openViewer:
        context.push('/note/${note.id}', extra: userId);
    }
  }

  /// 내용이 화면보다 짧아도 당길 수 있어야 한다 — 새로고침이 가장 필요한 곳이
  /// 목록이 비어 보이는 순간이다.
  Widget _fillViewport(BuildContext context, Widget child) => LayoutBuilder(
    builder: (context, constraints) => ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: constraints.maxHeight,
          child: Center(child: child),
        ),
      ],
    ),
  );

  Widget _emptyState(BuildContext context, NotesStore store) {
    final message = store.searchText.trim().isNotEmpty
        ? '검색 결과가 없습니다'
        : switch (store.viewMode) {
            NoteViewMode.active => '아직 노트가 없습니다',
            NoteViewMode.archived => '보관한 노트가 없습니다',
            NoteViewMode.trash => '휴지통이 비어 있습니다',
          };
    final icon = switch (store.viewMode) {
      NoteViewMode.active => Icons.inbox_outlined,
      NoteViewMode.archived => Icons.archive_outlined,
      NoteViewMode.trash => Icons.delete_outline,
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 40),
        const SizedBox(height: 8),
        Text(message),
      ],
    );
  }
}
