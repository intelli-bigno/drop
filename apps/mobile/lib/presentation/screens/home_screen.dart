import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:drop_mobile/data/models/models.dart';
import 'package:drop_mobile/data/repositories/attachments_repository.dart';
import 'package:drop_mobile/presentation/providers/notes_provider.dart';
import 'package:drop_mobile/presentation/providers/recording_provider.dart';
import 'package:drop_mobile/presentation/providers/share_intent_provider.dart';
import 'package:drop_mobile/presentation/providers/deep_link_provider.dart';
import 'package:drop_mobile/presentation/providers/selection_provider.dart';
import 'package:drop_mobile/presentation/widgets/action_buttons.dart';
import 'package:drop_mobile/presentation/widgets/note_card.dart';
import 'package:drop_mobile/presentation/widgets/note_composer_sheet.dart';
import 'package:drop_mobile/presentation/widgets/view_mode_selector.dart';
import 'package:drop_mobile/presentation/widgets/category_filter.dart';
import 'package:drop_mobile/presentation/widgets/selection_action_bar.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _sharedContentHandled = false;
  bool _deepLinkHandled = false;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Check for shared content and deep links after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForSharedContent();
      _checkForDeepLink();
    });
  }

  void _checkForDeepLink() {
    if (_deepLinkHandled) return;

    final deepLinkState = ref.read(deepLinkProvider);
    debugPrint('[HomeScreen] Checking deep link: ${deepLinkState.action}, handled: ${deepLinkState.handled}');
    if (deepLinkState.action != DeepLinkAction.none && !deepLinkState.handled) {
      _deepLinkHandled = true;
      ref.read(deepLinkProvider.notifier).markHandled();
      _handleDeepLinkAction(deepLinkState.action);
    }
  }

  void _handleDeepLinkAction(DeepLinkAction action) {
    switch (action) {
      case DeepLinkAction.record:
        _startRecording();
        break;
      case DeepLinkAction.memo:
        _openComposer(context);
        break;
      case DeepLinkAction.camera:
        _captureFromCamera();
        break;
      case DeepLinkAction.gallery:
        _pickFromGallery();
        break;
      case DeepLinkAction.none:
        break;
    }
  }

  void _checkForSharedContent() {
    if (_sharedContentHandled) return;

    final sharedContent = ref.read(shareIntentProvider);
    debugPrint('[HomeScreen] Checking shared content: ${sharedContent.hasContent}');
    if (sharedContent.hasContent) {
      _sharedContentHandled = true;
      _openComposerWithSharedContent(sharedContent);
    }
    // Note: Don't set _sharedContentHandled = true here if no content
    // The async getInitialMedia might not have completed yet
  }

  Future<void> _openComposerWithSharedContent(SharedContent content) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => NoteComposerSheet(
        sharedMedia: content.mediaFiles.isNotEmpty ? content.mediaFiles : null,
        sharedText: content.text,
      ),
    );

    // Clear shared content after handling
    if (result == true) {
      ref.read(shareIntentProvider.notifier).clearSharedContent();
    }
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesProvider);
    final recordingState = ref.watch(recordingProvider);
    final selectionState = ref.watch(selectionProvider);
    final isSelectionMode = selectionState.isSelectionMode;

    // Listen for new shared content
    ref.listen<SharedContent>(shareIntentProvider, (previous, next) {
      debugPrint('[HomeScreen] Share content changed: ${next.hasContent}, handled: $_sharedContentHandled');
      if (next.hasContent && !_sharedContentHandled) {
        _sharedContentHandled = true;
        _openComposerWithSharedContent(next);
      }
    });

    // Listen for deep links (app already running, widget tapped)
    ref.listen<DeepLinkState>(deepLinkProvider, (previous, next) {
      debugPrint('[HomeScreen] Deep link changed: ${next.action}, handled: ${next.handled}');
      if (next.action != DeepLinkAction.none && !next.handled) {
        ref.read(deepLinkProvider.notifier).markHandled();
        _handleDeepLinkAction(next.action);
      }
    });

    // Listen for recording errors
    ref.listen<RecordingState>(recordingProvider, (previous, next) {
      if (next.error != null && previous?.error != next.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: Colors.red,
          ),
        );
      }
    });

    final viewMode = ref.watch(viewModeProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: isSelectionMode
          ? _buildSelectionAppBar(context, ref, selectionState)
          : _buildNormalAppBar(context, ref, viewMode),
      body: Column(
        children: [
          // Notes content (includes ViewModeSelector and CategoryFilter as scrollable headers)
          Expanded(
            child: notesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      '오류가 발생했습니다',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(notesProvider),
                      child: const Text('다시 시도'),
                    ),
                  ],
                ),
              ),
              data: (notes) => _NoteFeed(isSelectionMode: isSelectionMode),
            ),
          ),
          // Selection Action Bar
          if (isSelectionMode) const SelectionActionBar(),
        ],
      ),
      floatingActionButton: !isSelectionMode && viewMode == NoteViewMode.active
          ? ActionButtons(
              isRecording: recordingState.isRecording,
              onAddPressed: () => _openComposer(context),
              onRecordPressed: () => _startRecording(),
              onCameraPressed: () => _captureFromCamera(),
              onGalleryPressed: () => _pickFromGallery(),
            )
          : null,
    );
  }

  AppBar _buildNormalAppBar(BuildContext context, WidgetRef ref, NoteViewMode viewMode) {
    return AppBar(
      backgroundColor: const Color(0xFF1A1A1A),
      elevation: 0,
      title: const Text(
        'DROP',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        // Selection mode button
        IconButton(
          icon: const Icon(Icons.checklist, color: Colors.white70),
          onPressed: () {
            ref.read(selectionProvider.notifier).enterSelectionMode();
          },
          tooltip: '선택',
        ),
        if (viewMode == NoteViewMode.trash)
          TextButton(
            onPressed: () => _showEmptyTrashDialog(context, ref),
            child: const Text(
              '비우기',
              style: TextStyle(color: Colors.red),
            ),
          ),
      ],
    );
  }

  AppBar _buildSelectionAppBar(BuildContext context, WidgetRef ref, SelectionState selectionState) {
    final filteredNotes = ref.watch(filteredNotesGroupedByDateProvider);
    final allNoteIds = filteredNotes.values.expand((items) => items.map((item) => item.note.id)).toList();
    final allSelected = allNoteIds.isNotEmpty && allNoteIds.every((id) => selectionState.selectedIds.contains(id));

    return AppBar(
      backgroundColor: const Color(0xFF1A1A1A),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.white),
        onPressed: () {
          ref.read(selectionProvider.notifier).exitSelectionMode();
        },
      ),
      title: Text(
        '${selectionState.selectedCount}개 선택',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (allSelected) {
              ref.read(selectionProvider.notifier).deselectAll();
            } else {
              ref.read(selectionProvider.notifier).selectAll(allNoteIds);
            }
          },
          child: Text(
            allSelected ? '선택 해제' : '전체 선택',
            style: const TextStyle(color: Color(0xFF4A9EFF)),
          ),
        ),
      ],
    );
  }

  Future<void> _showEmptyTrashDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text(
          '휴지통 비우기',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          '휴지통의 모든 노트가 영구적으로 삭제됩니다. 이 작업은 되돌릴 수 없습니다.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              '비우기',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(notesProvider.notifier).emptyTrash();
    }
  }

  Future<void> _openComposer(BuildContext context, {String? parentId}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => NoteComposerSheet(parentId: parentId),
    );
  }

  void _startRecording() {
    HapticFeedback.mediumImpact();
    ref.read(recordingProvider.notifier).startRecording();
  }

  Future<void> _captureFromCamera() async {
    HapticFeedback.mediumImpact();
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (image != null) {
        await _createNoteWithMedia([image]);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('카메라에 접근할 수 없습니다')),
        );
      }
    }
  }

  Future<void> _pickFromGallery() async {
    HapticFeedback.mediumImpact();
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage(
        imageQuality: 85,
      );
      if (images.isNotEmpty) {
        await _createNoteWithMedia(images);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('갤러리에 접근할 수 없습니다')),
        );
      }
    }
  }

  Future<void> _createNoteWithMedia(List<XFile> images) async {
    try {
      // Create note first (empty content for media-only note)
      final note = await ref
          .read(notesProvider.notifier)
          .createNote(content: '', parentId: null);

      // Upload attachments
      final attachmentsRepo = ref.read(attachmentsRepositoryProvider);
      for (final image in images) {
        try {
          final file = File(image.path);
          if (!await file.exists()) continue;

          final attachment = await attachmentsRepo.createImageAttachment(
            noteId: note.id,
            file: file,
          );
          ref.read(notesProvider.notifier).addAttachmentToNote(note.id, attachment);
        } catch (e) {
          debugPrint('Failed to upload attachment: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${images.length}개 이미지로 노트 생성됨'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('노트를 생성하지 못했습니다')),
        );
      }
    }
  }
}

class _NoteFeed extends ConsumerWidget {
  final bool isSelectionMode;

  const _NoteFeed({required this.isSelectionMode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewMode = ref.watch(viewModeProvider);
    final grouped = ref.watch(filteredNotesGroupedByDateProvider);
    final sortedDates = grouped.keys.toList();
    final selectionState = ref.watch(selectionProvider);

    // Build header widgets (ViewModeSelector + CategoryFilter)
    final headerWidgets = <Widget>[
      if (!isSelectionMode)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ViewModeSelector(),
        ),
      if (!isSelectionMode && viewMode == NoteViewMode.active)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: CategoryFilter(),
        ),
    ];

    if (sortedDates.isEmpty) {
      return Column(
        children: [
          ...headerWidgets,
          Expanded(child: _EmptyState(viewMode: viewMode)),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.refresh(notesProvider.future),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
        itemCount: sortedDates.length + 1, // +1 for header
        itemBuilder: (context, index) {
          // Header item (ViewModeSelector + CategoryFilter)
          if (index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: headerWidgets,
            );
          }

          final dateIndex = index - 1;
          final date = sortedDates[dateIndex];
          final dateNotes = grouped[date]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: 12, top: dateIndex > 0 ? 24 : 8),
                child: Text(
                  date,
                  style: const TextStyle(
                    color: Color(0xFF9A9A9A),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              ...dateNotes.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: NoteCard(
                      note: item.note,
                      depth: item.depth,
                      viewMode: viewMode,
                      isSelectionMode: isSelectionMode,
                      isSelected: selectionState.selectedIds.contains(item.note.id),
                      onEdit: () => _openEditComposer(context, item.note),
                      onReply: () => _openReplyComposer(context, item.note.id),
                      onLongPress: () {
                        if (!isSelectionMode) {
                          HapticFeedback.mediumImpact();
                          ref.read(selectionProvider.notifier).enterSelectionMode(item.note.id);
                        }
                      },
                      onSelect: () {
                        ref.read(selectionProvider.notifier).toggleSelection(item.note.id);
                      },
                    ),
                  )),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openEditComposer(
    BuildContext context,
    Note note,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => NoteComposerSheet(note: note),
    );
  }

  Future<void> _openReplyComposer(
    BuildContext context,
    String parentId,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => NoteComposerSheet(parentId: parentId),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final NoteViewMode viewMode;

  const _EmptyState({required this.viewMode});

  @override
  Widget build(BuildContext context) {
    final (icon, title, subtitle) = switch (viewMode) {
      NoteViewMode.active => (
          Icons.note_add_outlined,
          '노트가 없습니다',
          '+ 버튼을 눌러 첫 번째 노트를 만드세요',
        ),
      NoteViewMode.archived => (
          Icons.archive_outlined,
          '보관된 노트가 없습니다',
          '보관한 노트가 여기에 표시됩니다',
        ),
      NoteViewMode.trash => (
          Icons.delete_outline,
          '휴지통이 비어 있습니다',
          '삭제한 노트가 여기에 표시됩니다',
        ),
    };

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[400],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ],
      ),
    );
  }
}
