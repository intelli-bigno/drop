/// 홈 피드 — 앱 사용 시간의 대부분이 여기다. iOS `HomeView.swift` 대응 (BRU-156).
///
/// 날짜 묶기·계층 들여쓰기·필터·정렬은 전부 drop_core의 순수 로직이 정하고,
/// 이 화면은 그 결과(`NoteSection` → `NoteRow`)를 그대로 그리기만 한다.
///
/// 목록의 조각(행·섹션 머리글·빈 상태)은 전부 `lib/widgets`의 위젯이다 —
/// 화면 안 private 메서드로 두면 쇼케이스도 테스트도 그 자리에 닿지 못한다 (BRU-193).
library;

import 'dart:async';
import 'dart:io';

import 'package:drop_core/drop_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../environment/providers.dart';
import '../links/deep_link_router.dart';
import '../native/native_shell.dart';
import '../notes/comments_controller.dart';
import '../notes/note_tap.dart';
import '../notes/notes_controller.dart';
import '../theme/drop_theme.dart';
import '../widgets/drop_feedback.dart';
import '../widgets/drop_notice.dart';
import '../widgets/drop_swipe_row.dart';
import '../widgets/note_card.dart';
import '../widgets/note_empty_state.dart';
import '../widgets/note_filter_bar.dart';
import '../widgets/note_group.dart';
import '../widgets/note_section_header.dart';
import '../widgets/selection_action_bar.dart';
import 'composer_sheet.dart';
import 'home_menu_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  /// 목록 상태의 스코프 키. 사용자가 바뀌면 목록도 처음부터 다시 만든다.
  final String? userId;

  const HomeScreen({super.key, required this.userId});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  /// 날짜 섹션 묶기는 drop_core의 순수 함수가 한다 — 자정·시간대 경계를
  /// 화면 코드에 두면 검증할 방법이 없다.
  static const _grouper = NoteDateGrouper();

  String? get userId => widget.userId;

  /// 목록에서 한 번에 한 줄만 열려 있게 한다 (BRU-207). 화면이 하나 들고
  /// 행마다 나눠 준다 — 줄끼리 서로를 모르면 두 줄이 동시에 열린다.
  final DropSwipeCoordinator _swipe = DropSwipeCoordinator();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 콜드 스타트에서는 딥링크가 홈보다 먼저 도착해 있다 (iOS DropRouter의
    // "보관 후 소비"와 같은 이유) — 첫 프레임 뒤에 밀린 것부터 소비한다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _consumePendingLinks();
      // 공유 시트로 들어온 항목을 여기서 비운다. 확장은 적어 두기만 한다.
      unawaited(_drainSharedInbox());
      // iOS `.onChange(of: notes.allNotes, initial: true)`의 initial 대응.
      unawaited(_publishWidgetSnapshot());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _swipe.dispose();
    super.dispose();
  }

  /// 앱이 살아 있는 채로 공유가 들어오면 복귀 시점에 비운다
  /// (iOS `.onChange(of: scenePhase)` 대응).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_drainSharedInbox());
    }
  }

  /// 공유 시트로 들어온 항목을 노트로 만든다 (iOS `drainSharedInbox` 대응).
  ///
  /// 첨부 업로드가 실패해도 노트는 남긴다 — 사용자가 공유한 텍스트/링크까지
  /// 함께 잃는 것이 더 나쁘다.
  Future<void> _drainSharedInbox() async {
    final path = await ref.read(nativeShellProvider).appGroupContainerPath();
    if (path == null || !mounted) return;

    final inbox = SharedInbox(Directory('$path/inbox'));
    final List<SharedItem> items;
    try {
      items = inbox.drain();
    } catch (_) {
      return;
    }
    if (items.isEmpty) return;

    final notes = ref.read(notesControllerProvider(userId));
    final repository = ref.read(dropContainerProvider).attachmentsRepository;
    for (final item in items) {
      // 만들어진 노트를 그대로 받는다. 목록에서 되찾으면 고정 노트가
      // 맨 앞이라 남의 노트에 첨부가 붙는다 (BRU-43).
      final note = await notes.create(content: item.text);
      if (note == null) continue;

      for (final name in item.fileNames) {
        final file = File(inbox.filePath(name));
        try {
          await repository.upload(
            data: await file.readAsBytes(),
            fileName: name,
            type: AttachmentType.forFileName(name),
            noteId: note.id,
          );
        } catch (error) {
          notes.store.report(error);
        }
        try {
          file.deleteSync();
        } catch (_) {}
      }
    }
    await notes.load();
  }

  /// 딥링크 라우터에 보관된 요청을 화면 이동으로 바꾼다.
  /// iOS `HomeView`의 `.onChange(of: router.pending*)` 3종 대응.
  void _consumePendingLinks() {
    if (!mounted) return;
    final links = ref.read(deepLinkRouterProvider);

    final noteId = links.consumeNoteId();
    if (noteId != null) context.push('/note/$noteId', extra: userId);

    final composeText = links.consumeComposeText();
    if (composeText != null) {
      unawaited(
        showComposerSheet(
          context,
          ref.read(notesControllerProvider(userId)),
          target: ComposerTarget.newWithText(composeText),
        ),
      );
    }

    // 위젯의 카메라·갤러리 바로가기 (BRU-43). 화면 안의 첨부 경로와 같은 곳으로
    // 보낸다 — 위젯 전용 첨부 경로를 따로 만들면 두 길이 어긋난다.
    switch (links.consumeCapture()) {
      case QuickCapture.camera:
        unawaited(_addCameraNote());
      case QuickCapture.gallery:
        unawaited(_addGalleryNote());
      case null:
        break;
    }
  }

  /// 카메라로 찍은 한 장을 노트로 만든다 (BRU-43, iOS `addCameraNote` 대응).
  /// 첨부는 **방금 만든 그 노트**에 붙인다 — 목록에서 되찾으면 고정 노트가
  /// 맨 앞이라 남의 노트에 첨부가 붙는다.
  Future<void> _addCameraNote() async {
    final XFile? shot;
    try {
      shot = await ImagePicker().pickImage(source: ImageSource.camera);
    } catch (_) {
      // 시뮬레이터 등 카메라가 없는 기기 (iOS `cameraUnavailable` 대응).
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('카메라를 쓸 수 없습니다. 사진 보관함에서 골라 주세요.')),
        );
      }
      return;
    }
    if (shot == null) return;
    await _addMediaNote([shot], fileName: (_) => _cameraFileName());
  }

  static String _cameraFileName() =>
      'camera-${DateTime.now().millisecondsSinceEpoch ~/ 1000}.jpg';

  /// 보관함에서 고른 사진·영상을 노트 하나로 만든다 (iOS `addPhotoNote` 대응).
  Future<void> _addGalleryNote() async {
    final List<XFile> files;
    try {
      files = await ImagePicker().pickMultipleMedia(limit: 5);
    } catch (_) {
      return;
    }
    if (files.isEmpty) return;
    await _addMediaNote(files, fileName: (file) => file.name);
  }

  /// 빈 노트 하나를 만들고 파일들을 그 노트에 붙인다. 업로드가 실패해도
  /// 노트는 남긴다 — 오류는 목록의 오류 배너와 같은 자리로 흐른다.
  Future<void> _addMediaNote(
    List<XFile> files, {
    required String Function(XFile file) fileName,
  }) async {
    final notes = ref.read(notesControllerProvider(userId));
    final note = await notes.create(content: '');
    if (note == null) return;

    final repository = ref.read(dropContainerProvider).attachmentsRepository;
    for (final file in files) {
      final name = fileName(file);
      try {
        await repository.upload(
          data: await file.readAsBytes(),
          fileName: name,
          type: AttachmentType.forFileName(name),
          noteId: note.id,
        );
      } catch (error) {
        notes.store.report(error);
      }
    }
    await notes.load();
  }

  /// 마지막으로 위젯에 적은 줄들. 같은 내용을 다시 적고 리로드하지 않기 위한 기억.
  List<WidgetNote>? _publishedWidgetNotes;

  /// 위젯이 읽을 요약을 App Group에 적어 두고, 위젯을 다시 그리게 한다
  /// (iOS `WidgetSnapshotPublisher` 대응). 실패해도 앱은 그대로 간다 —
  /// 위젯이 한 박자 늦게 갱신될 뿐이다.
  Future<void> _publishWidgetSnapshot() async {
    final store = ref.read(notesControllerProvider(userId)).store;
    final snapshot = WidgetSnapshot.fromNotes(store.allNotes);
    if (_sameWidgetNotes(_publishedWidgetNotes, snapshot.notes)) return;

    final shell = ref.read(nativeShellProvider);
    final path = await shell.appGroupContainerPath();
    if (path == null) return;
    try {
      WidgetSnapshotStore(Directory(path)).write(snapshot);
    } catch (_) {
      return;
    }
    _publishedWidgetNotes = snapshot.notes;
    await shell.reloadWidgets();
  }

  static bool _sameWidgetNotes(List<WidgetNote>? a, List<WidgetNote> b) {
    if (a == null || a.length != b.length) return false;
    for (var i = 0; i < a.length; i += 1) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // 앱이 살아 있는 채로 딥링크가 들어오면 그 시점에 소비한다.
    ref.listen(deepLinkRouterProvider, (_, links) {
      if (links.hasPending) _consumePendingLinks();
    });

    // 목록이 바뀌는 경로가 여럿이라(불러오기·작성·수정·삭제) 각 호출부에
    // 끼워 넣지 않고, 결과인 목록 자체를 한 곳에서 본다
    // (iOS `.onChange(of: notes.allNotes)` 대응).
    ref.listen(notesControllerProvider(userId), (previous, next) {
      unawaited(_publishWidgetSnapshot());
    });

    final container = ref.watch(dropContainerProvider);
    final notes = ref.watch(notesControllerProvider(userId));
    final comments = ref.watch(commentsControllerProvider(userId));
    final store = notes.store;

    return PopScope(
      // 선택 모드에서 뒤로 가기는 앱을 나가는 게 아니라 선택을 푸는 것이다.
      canPop: !store.isSelecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && store.isSelecting) notes.clearSelection();
      },
      child: Scaffold(
        appBar: AppBar(
          // 보기 전환이 ⋯ 메뉴로 들어가 화면에 안 보이므로, 지금 어디를 보고
          // 있는지는 제목이 알려 준다.
          title: AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            // 앱바에 아이콘은 달지 않는다 — 워드마크 옆에 앱 아이콘을 두면
            // 같은 말을 두 번 하고 정렬선만 어지럽힌다 (BRU-207 피드백).
            child: Text(_title(store), key: ValueKey(_title(store))),
          ),
          leading: store.isSelecting
              ? TextButton(
                  onPressed: notes.clearSelection,
                  child: const Text('취소'),
                )
              : null,
          leadingWidth: store.isSelecting ? 72 : null,
          actions: [
            if (!store.isSelecting) _menu(ref, notes, container.isPreview),
            const SizedBox(width: DropTokenSpace.x2),
          ],
        ),
        body: Column(
          children: [
            NoteFilterBar(controller: notes),
            if (store.errorMessage != null)
              DropNotice(
                message: store.errorMessage!,
                onDismiss: notes.dismissError,
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
        // 선택 모드에 들어가면 FAB은 줄어들며 사라지고, 액션 바가 아래서 올라온다 —
        // 둘이 툭 바뀌면 화면이 "깜빡"한다.
        floatingActionButton: AnimatedScale(
          scale: store.isSelecting ? 0 : 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutBack,
          child: FloatingActionButton(
            tooltip: '새 노트',
            // 편집·답글 타깃은 뷰어(BRU-157)가 같은 입구로 연다.
            onPressed: store.isSelecting
                ? null
                : () => showComposerSheet(context, notes),
            child: const Icon(Icons.add),
          ),
        ),
        bottomNavigationBar: AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: store.isSelecting
              ? SelectionActionBar(controller: notes)
              : const SizedBox(width: double.infinity),
        ),
      ),
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

  /// 보기 전환·테마·로그아웃. 팝업 메뉴가 아니라 바닥 시트다 — 엄지가 닿는 곳에
  /// 구역별 세그먼트로 서고, 지금 상태가 켜진 칸으로 보인다.
  Widget _menu(WidgetRef ref, NotesController notes, bool isPreview) {
    final store = notes.store;
    return IconButton(
      icon: const Icon(Icons.more_horiz),
      tooltip: '더보기',
      onPressed: () async {
        final choice = await showHomeMenuSheet(
          context,
          current: store.viewMode,
          isPreview: isPreview,
        );
        switch (choice) {
          case HomeMenuView(:final mode):
            DropHaptics.select();
            notes.setViewMode(mode);
          case HomeMenuSignOut():
            ref.read(authControllerProvider).signOut();
          case null:
            break;
        }
      },
    );
  }

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
      return _fillViewport(
        context,
        NoteEmptyState(
          viewMode: store.viewMode,
          isSearching: store.searchText.trim().isNotEmpty,
          isFiltered:
              store.category != NoteCategory.all ||
              store.todoFilter != TodoFilter.off ||
              store.selectedTagId != null,
        ),
      );
    }

    final sections = _grouper.sections(rows);
    // 목록이 움직이면 열린 줄은 닫는다 — 스크롤하는 동안 열린 채로 따라오면
    // 손이 가려던 곳이 아닌 데서 동작이 눌린다.
    return NotificationListener<ScrollStartNotification>(
      onNotification: (_) {
        _swipe.closeAll();
        return false;
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        // 마지막 행이 FAB 밑에 깔리지 않게 — 스크롤 끝에 한 화면 분량의 숨을 둔다.
        padding: const EdgeInsets.only(
          bottom: DropTokenSpace.x8 + DropTokenSpace.x5,
        ),
        children: [
          for (final (index, section) in sections.indexed) ...[
            NoteSectionHeader(
              title: section.title,
              count: section.rows.length,
              isFirst: index == 0,
            ),
            NoteGroup(
              // 묶음의 모든 행이 고정 노트면 고정 묶음이다 — 제목 문자열에 기대지 않는다.
              isPinned: section.rows.every((row) => row.note.isPinned),
              children: [
                for (final row in section.rows)
                  DropSwipeRow(
                    key: ValueKey('note-${row.id}'),
                    id: row.id,
                    coordinator: _swipe,
                    // 선택 중에는 끈다 — 고르려던 손이 스와이프로 새면 안 된다.
                    enabled: !store.isSelecting,
                    actions: _pinAction(context, notes, row.note),
                    child: NoteCard(
                      row: row,
                      isSelecting: store.isSelecting,
                      isSelected: store.selectedIds.contains(row.id),
                      commentCount: comments.countFor(row.id),
                      onTap: () =>
                          _handleTap(context, notes, row.note, count: 1),
                      onDoubleTap: () =>
                          _handleTap(context, notes, row.note, count: 2),
                      // 롱프레스는 선택 모드 하나만 쓴다. 손끝에 "모드가 바뀌었다"를 알린다.
                      onLongPress: () {
                        if (!store.isSelecting) DropHaptics.impact();
                        notes.toggleSelection(row.id);
                      },
                      onToggleCompleted: () {
                        DropHaptics.select();
                        notes.setCompleted(
                          row.id,
                          completed: !row.note.isCompleted,
                        );
                      },
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// 왼쪽으로 밀면 나오는 동작 — 지금은 상단 고정 하나다 (BRU-207).
  ///
  /// 색은 iOS와 같은 액센트다(`DropTheme.SwipeAction.pin` → `Colors.accent`).
  /// 휴지통에서는 내주지 않는다 — 지울 노트를 맨 위에 꽂는 것은 뜻이 없다.
  List<DropSwipeAction> _pinAction(
    BuildContext context,
    NotesController notes,
    Note note,
  ) {
    if (notes.store.viewMode == NoteViewMode.trash) return const [];
    final colors = DropColors.of(context);
    final pinned = note.isPinned;
    return [
      DropSwipeAction(
        label: pinned ? '고정 해제' : '고정',
        icon: pinned ? Icons.push_pin_outlined : Icons.push_pin,
        background: colors.accent,
        foreground: colors.textOnAccent,
        onPressed: () => notes.setPinned(note.id, isPinned: !pinned),
      ),
    ];
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
        // 복사는 화면에 아무 흔적도 안 남기는 동작이다 — 되먹임이 없으면
        // 사용자는 더블탭이 먹었는지 모른다.
        DropHaptics.impact();
        showDropToast(context, '본문을 복사했어요');
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
}
