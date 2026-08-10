import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:drop_mobile/core/utils/time_utils.dart';
import 'package:drop_mobile/data/models/models.dart';
import 'package:drop_mobile/data/repositories/attachments_repository.dart';
import 'package:drop_mobile/presentation/providers/notes_provider.dart';
import 'package:drop_mobile/presentation/providers/recording_provider.dart';
import 'package:drop_mobile/presentation/widgets/waveform_view.dart';
import 'package:drop_mobile/presentation/widgets/media_viewer.dart';

class NoteCard extends ConsumerWidget {
  final Note note;
  final int depth;
  final NoteViewMode viewMode;
  final VoidCallback? onEdit;
  final VoidCallback? onReply;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback? onLongPress;
  final VoidCallback? onSelect;

  const NoteCard({
    super.key,
    required this.note,
    this.depth = 0,
    this.viewMode = NoteViewMode.active,
    this.onEdit,
    this.onReply,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onLongPress,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordingState = ref.watch(recordingProvider);
    final isRecordingThisNote = recordingState.activeNoteId == note.id;
    final isRecording = isRecordingThisNote && recordingState.isRecording;
    final isTranscribing = isRecordingThisNote && recordingState.isTranscribing;

    final cardContent = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF4A9EFF).withValues(alpha: 0.15)
            : const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
        border: isRecording
            ? Border.all(color: Colors.red.withValues(alpha: 0.5), width: 2)
            : isTranscribing
            ? Border.all(
                color: const Color(0xFF4A9EFF).withValues(alpha: 0.5),
                width: 2,
              )
            : isSelected
            ? Border.all(
                color: const Color(0xFF4A9EFF).withValues(alpha: 0.5),
                width: 2,
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(
            context,
            ref,
            isRecording: isRecording,
            isTranscribing: isTranscribing,
          ),

          // Recording state UI
          if (isRecording) _buildRecordingContent(context, ref, recordingState),

          // Transcribing state UI
          if (isTranscribing) _buildTranscribingContent(context),

          // Normal content (show only when not recording/transcribing)
          if (!isRecording && !isTranscribing) ...[
            // Content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                note.content.isEmpty ? '(빈 노트)' : note.content,
                style: TextStyle(
                  color: note.content.isEmpty
                      ? const Color(0xFF666666)
                      : const Color(0xFFE0E0E0),
                  fontSize: 15,
                  height: 1.6,
                  fontStyle: note.content.isEmpty
                      ? FontStyle.italic
                      : FontStyle.normal,
                ),
              ),
            ),
            // Attachments
            if (note.attachments.isNotEmpty) _buildAttachments(context),
            // Tags
            if (note.tags.isNotEmpty) _buildTags(),
          ],
        ],
      ),
    );

    // Card with optional checkbox for selection mode
    final cardWithCheckbox = Row(
      children: [
        if (isSelectionMode) _buildCheckbox(),
        Expanded(child: cardContent),
      ],
    );

    // Wrap with Slidable for swipe actions (disabled in selection mode)
    final slidableCard = isSelectionMode
        ? cardWithCheckbox
        : Slidable(
            key: ValueKey(note.id),
            endActionPane: _buildEndActionPane(context, ref),
            startActionPane: _buildStartActionPane(context, ref),
            child: cardContent,
          );

    return GestureDetector(
      onTap: (isRecording || isTranscribing)
          ? null
          : isSelectionMode
          ? onSelect
          : null,
      onDoubleTap: (isRecording || isTranscribing || isSelectionMode)
          ? null
          : onEdit,
      onLongPress: (isRecording || isTranscribing) ? null : onLongPress,
      child: Padding(
        padding: EdgeInsets.only(left: depth * 24.0),
        child: depth > 0
            ? IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 2,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF444444),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                    Expanded(child: slidableCard),
                  ],
                ),
              )
            : slidableCard,
      ),
    );
  }

  Widget _buildCheckbox() {
    return Container(
      width: 40,
      padding: const EdgeInsets.all(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? const Color(0xFF4A9EFF) : Colors.transparent,
          border: Border.all(
            color: isSelected
                ? const Color(0xFF4A9EFF)
                : const Color(0xFF666666),
            width: 2,
          ),
        ),
        child: isSelected
            ? const Icon(Icons.check, size: 16, color: Colors.white)
            : null,
      ),
    );
  }

  ActionPane? _buildEndActionPane(BuildContext context, WidgetRef ref) {
    switch (viewMode) {
      case NoteViewMode.active:
        return ActionPane(
          motion: const BehindMotion(),
          children: [
            SlidableAction(
              onPressed: (_) => _archiveNote(context, ref),
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              icon: Icons.archive_outlined,
              label: '보관',
            ),
            SlidableAction(
              onPressed: (_) => _deleteNote(context, ref),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              icon: Icons.delete_outline,
              label: '삭제',
            ),
          ],
        );
      case NoteViewMode.archived:
        return ActionPane(
          motion: const BehindMotion(),
          children: [
            SlidableAction(
              onPressed: (_) => _unarchiveNote(context, ref),
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white,
              icon: Icons.unarchive_outlined,
              label: '해제',
            ),
            SlidableAction(
              onPressed: (_) => _deleteNote(context, ref),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              icon: Icons.delete_outline,
              label: '삭제',
            ),
          ],
        );
      case NoteViewMode.trash:
        return ActionPane(
          motion: const BehindMotion(),
          children: [
            SlidableAction(
              onPressed: (_) => _showPermanentDeleteConfirmation(context, ref),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              icon: Icons.delete_forever,
              label: '영구삭제',
            ),
          ],
        );
    }
  }

  ActionPane? _buildStartActionPane(BuildContext context, WidgetRef ref) {
    switch (viewMode) {
      case NoteViewMode.active:
        return ActionPane(
          motion: const BehindMotion(),
          children: [
            SlidableAction(
              onPressed: (_) => ref.read(notesProvider.notifier).togglePinNote(note.id),
              backgroundColor: note.isPinned
                  ? const Color(0xFF666666)
                  : const Color(0xFFFFAA00),
              foregroundColor: Colors.white,
              icon: note.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
              label: note.isPinned ? '해제' : '고정',
            ),
            SlidableAction(
              onPressed: (_) {
                if (onReply != null) {
                  onReply!();
                } else {
                  ref
                      .read(notesProvider.notifier)
                      .createNote(parentId: note.id);
                }
              },
              backgroundColor: const Color(0xFF4A9EFF),
              foregroundColor: Colors.white,
              icon: Icons.reply,
              label: '댓글',
            ),
          ],
        );
      case NoteViewMode.archived:
        return null;
      case NoteViewMode.trash:
        return ActionPane(
          motion: const BehindMotion(),
          children: [
            SlidableAction(
              onPressed: (_) => _restoreNote(context, ref),
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              icon: Icons.restore,
              label: '복원',
            ),
          ],
        );
    }
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref, {
    required bool isRecording,
    required bool isTranscribing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF333333))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (isRecording)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              if (isTranscribing)
                Container(
                  width: 16,
                  height: 16,
                  margin: const EdgeInsets.only(right: 8),
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF4A9EFF),
                    ),
                  ),
                ),
              if (!isRecording && !isTranscribing) ...[
                // Pin indicator
                if (note.isPinned)
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    child: const Icon(
                      Icons.push_pin,
                      color: Color(0xFFFFAA00),
                      size: 12,
                    ),
                  ),
                // Priority indicator
                if (note.priority > 0)
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    child: Text(
                      '!' * note.priority,
                      style: TextStyle(
                        color: _getPriorityColor(note.priority),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                // Display ID
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  child: Text(
                    '#${note.displayId}',
                    style: const TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
              Text(
                isRecording
                    ? '녹음 중...'
                    : isTranscribing
                    ? '변환 중...'
                    : formatRelativeTime(note.createdAt),
                style: TextStyle(
                  color: isRecording
                      ? Colors.red
                      : isTranscribing
                      ? const Color(0xFF4A9EFF)
                      : const Color(0xFF9A9A9A),
                  fontSize: 12,
                  fontWeight: isRecording || isTranscribing
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
            ],
          ),
          if (isRecording || isTranscribing)
            SizedBox(
              width: 44,
              height: 44,
              child: IconButton(
                onPressed: isRecording
                    ? () =>
                          ref.read(recordingProvider.notifier).cancelRecording()
                    : null,
                tooltip: '녹음 취소',
                padding: EdgeInsets.zero,
                icon: Icon(
                  Icons.close,
                  color: isTranscribing
                      ? const Color(0xFF444444)
                      : const Color(0xFF9A9A9A),
                  size: 18,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecordingContent(
    BuildContext context,
    WidgetRef ref,
    RecordingState recordingState,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Waveform
          SizedBox(
            height: 48,
            child: WaveformView(
              levels: recordingState.audioLevels,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 12),
          // Time display
          Text(
            recordingState.formattedTime,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          // Control buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Cancel button
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  ref.read(recordingProvider.notifier).cancelRecording();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A3A3A),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '취소',
                    style: TextStyle(color: Color(0xFF9A9A9A), fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Stop button
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  ref.read(recordingProvider.notifier).stopRecording();
                },
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTranscribingContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.graphic_eq, color: Color(0xFF4A9EFF), size: 32),
          const SizedBox(height: 12),
          const Text(
            '음성을 텍스트로 변환 중...',
            style: TextStyle(color: Color(0xFFE0E0E0), fontSize: 14),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: const LinearProgressIndicator(
              minHeight: 3,
              backgroundColor: Color(0xFF3A3A3A),
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A9EFF)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachments(BuildContext context) {
    // Separate attachments by type for better layout
    final imageAttachments = note.attachments
        .where((a) => a.type == AttachmentType.image)
        .toList();
    final videoAttachments = note.attachments
        .where((a) => a.type == AttachmentType.video)
        .toList();
    final audioAttachments = note.attachments
        .where((a) => a.type == AttachmentType.audio)
        .toList();
    final instagramAttachments = note.attachments
        .where((a) => a.type == AttachmentType.instagram)
        .toList();
    final otherAttachments = note.attachments
        .where(
          (a) =>
              a.type != AttachmentType.image &&
              a.type != AttachmentType.video &&
              a.type != AttachmentType.audio &&
              a.type != AttachmentType.instagram,
        )
        .toList();

    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF333333))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image/Video Gallery Grid
          if (imageAttachments.isNotEmpty || videoAttachments.isNotEmpty)
            _buildMediaGallery(context, [
              ...imageAttachments,
              ...videoAttachments,
            ]),

          // Instagram attachments
          if (instagramAttachments.isNotEmpty)
            _buildInstagramAttachments(instagramAttachments),

          // Audio and other attachments as chips
          if (audioAttachments.isNotEmpty || otherAttachments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...audioAttachments.map(
                    (a) => _AudioAttachmentChip(attachment: a),
                  ),
                  ...otherAttachments.map((a) => _buildAttachmentChip(a)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMediaGallery(
    BuildContext context,
    List<Attachment> mediaAttachments,
  ) {
    if (mediaAttachments.isEmpty) return const SizedBox.shrink();

    // Different layouts based on count
    if (mediaAttachments.length == 1) {
      return _buildSingleMediaPreview(context, mediaAttachments, 0);
    } else if (mediaAttachments.length == 2) {
      return _buildTwoMediaGrid(context, mediaAttachments);
    } else {
      return _buildMultiMediaGrid(context, mediaAttachments);
    }
  }

  Widget _buildSingleMediaPreview(
    BuildContext context,
    List<Attachment> allMedia,
    int index,
  ) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: GestureDetector(
        onTap: () => _openMediaViewer(context, allMedia, index),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: _buildMediaPreview(allMedia[index], isThumbnail: false),
          ),
        ),
      ),
    );
  }

  void _openMediaViewer(
    BuildContext context,
    List<Attachment> mediaAttachments,
    int initialIndex,
  ) {
    MediaViewer.show(
      context,
      mediaAttachments: mediaAttachments,
      initialIndex: initialIndex,
    );
  }

  Widget _buildTwoMediaGrid(
    BuildContext context,
    List<Attachment> attachments,
  ) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _openMediaViewer(context, attachments, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: _buildMediaPreview(attachments[0], isThumbnail: true),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => _openMediaViewer(context, attachments, 1),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: _buildMediaPreview(attachments[1], isThumbnail: true),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiMediaGrid(
    BuildContext context,
    List<Attachment> attachments,
  ) {
    final displayCount = attachments.length > 4 ? 3 : attachments.length;
    final hasMore = attachments.length > 4;
    final remaining = attachments.length - 3;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1,
        ),
        itemCount: displayCount,
        itemBuilder: (context, index) {
          final attachment = attachments[index];
          final isLast = index == displayCount - 1;

          return GestureDetector(
            onTap: () => _openMediaViewer(context, attachments, index),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildMediaPreview(attachment, isThumbnail: true),
                  if (hasMore && isLast)
                    Container(
                      color: Colors.black54,
                      child: Center(
                        child: Text(
                          '+$remaining',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMediaPreview(
    Attachment attachment, {
    required bool isThumbnail,
  }) {
    if (attachment.type == AttachmentType.image) {
      return _ImagePreview(attachment: attachment, isThumbnail: isThumbnail);
    } else if (attachment.type == AttachmentType.video) {
      return _VideoPreview(attachment: attachment, isThumbnail: isThumbnail);
    }
    return const SizedBox.shrink();
  }

  Widget _buildInstagramAttachments(List<Attachment> attachments) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: attachments.map((attachment) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _InstagramAttachmentCard(attachment: attachment),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAttachmentChip(Attachment attachment) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 200),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF242424),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getAttachmentIcon(attachment.type),
            color: const Color(0xFF9A9A9A),
            size: 14,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              attachment.filename ?? attachment.type.name,
              style: const TextStyle(color: Color(0xFF9A9A9A), fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTags() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF333333))),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: note.tags.map((tag) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF242424),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF333333)),
            ),
            child: Text(
              '#${tag.name}',
              style: const TextStyle(color: Color(0xFF4A9EFF), fontSize: 12),
            ),
          );
        }).toList(),
      ),
    );
  }

  IconData _getAttachmentIcon(AttachmentType type) {
    switch (type) {
      case AttachmentType.image:
        return Icons.image;
      case AttachmentType.video:
        return Icons.videocam;
      case AttachmentType.audio:
        return Icons.audiotrack;
      case AttachmentType.file:
        return Icons.attach_file;
      case AttachmentType.text:
        return Icons.text_snippet;
      case AttachmentType.instagram:
        return Icons.camera_alt;
      case AttachmentType.youtube:
        return Icons.play_circle_outline;
    }
  }

  Color _getPriorityColor(int priority) {
    switch (priority) {
      case 1:
        return const Color(0xFF4A9EFF); // Blue - low
      case 2:
        return const Color(0xFFFFA500); // Orange - medium
      case 3:
        return const Color(0xFFFF4444); // Red - high
      default:
        return const Color(0xFF9A9A9A);
    }
  }

  void _archiveNote(BuildContext context, WidgetRef ref) {
    ref.read(notesProvider.notifier).archiveNote(note.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('노트가 보관함으로 이동되었습니다'),
        action: SnackBarAction(
          label: '취소',
          onPressed: () =>
              ref.read(notesProvider.notifier).unarchiveNote(note.id),
        ),
      ),
    );
  }

  void _unarchiveNote(BuildContext context, WidgetRef ref) {
    ref.read(notesProvider.notifier).unarchiveNote(note.id);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('노트가 보관함에서 해제되었습니다')));
  }

  void _restoreNote(BuildContext context, WidgetRef ref) {
    ref.read(notesProvider.notifier).restoreNote(note.id);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('노트가 복원되었습니다')));
  }

  void _deleteNote(BuildContext context, WidgetRef ref) {
    ref.read(notesProvider.notifier).deleteNote(note.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('노트가 휴지통으로 이동되었습니다'),
        action: SnackBarAction(
          label: '취소',
          onPressed: () =>
              ref.read(notesProvider.notifier).restoreNote(note.id),
        ),
      ),
    );
  }

  void _showPermanentDeleteConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('영구 삭제', style: TextStyle(color: Colors.white)),
        content: const Text(
          '이 노트를 영구적으로 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.',
          style: TextStyle(color: Color(0xFFE0E0E0)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(notesProvider.notifier).permanentlyDeleteNote(note.id);
            },
            child: const Text('영구 삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// Image Preview Widget
class _ImagePreview extends ConsumerWidget {
  final Attachment attachment;
  final bool isThumbnail;

  const _ImagePreview({required this.attachment, required this.isThumbnail});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urlAsync = ref.watch(
      attachmentSignedUrlProvider(attachment.storagePath),
    );

    return urlAsync.when(
      data: (url) => CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: const Color(0xFF1A1A1A),
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorWidget: (context, url, error) => Container(
          color: const Color(0xFF1A1A1A),
          child: const Center(
            child: Icon(Icons.broken_image, color: Color(0xFF666666), size: 32),
          ),
        ),
      ),
      loading: () => Container(
        color: const Color(0xFF1A1A1A),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Container(
        color: const Color(0xFF1A1A1A),
        child: const Center(
          child: Icon(Icons.error_outline, color: Color(0xFF666666), size: 32),
        ),
      ),
    );
  }
}

// Video Preview Widget
class _VideoPreview extends ConsumerWidget {
  final Attachment attachment;
  final bool isThumbnail;

  const _VideoPreview({required this.attachment, required this.isThumbnail});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urlAsync = ref.watch(
      attachmentSignedUrlProvider(attachment.storagePath),
    );

    return urlAsync.when(
      data: (url) => Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: const Color(0xFF1A1A1A),
            child: const Center(
              child: Icon(Icons.videocam, color: Color(0xFF666666), size: 32),
            ),
          ),
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
        ],
      ),
      loading: () => Container(
        color: const Color(0xFF1A1A1A),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Container(
        color: const Color(0xFF1A1A1A),
        child: const Center(
          child: Icon(Icons.error_outline, color: Color(0xFF666666), size: 32),
        ),
      ),
    );
  }
}

// Instagram Attachment Card
class _InstagramAttachmentCard extends ConsumerWidget {
  final Attachment attachment;

  const _InstagramAttachmentCard({required this.attachment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF242424),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.camera_alt, color: Color(0xFFE4405F), size: 16),
              const SizedBox(width: 6),
              Text(
                'Instagram',
                style: const TextStyle(
                  color: Color(0xFFE4405F),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (attachment.authorName != null) ...[
                const SizedBox(width: 8),
                const Text('·', style: TextStyle(color: Color(0xFF666666))),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '@${attachment.authorName}',
                    style: const TextStyle(
                      color: Color(0xFF9A9A9A),
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          if (attachment.caption != null && attachment.caption!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              attachment.caption!,
              style: const TextStyle(
                color: Color(0xFFE0E0E0),
                fontSize: 13,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (attachment.originalUrl != null) ...[
            const SizedBox(height: 8),
            Text(
              attachment.originalUrl!,
              style: const TextStyle(
                color: Color(0xFF4A9EFF),
                fontSize: 11,
                decoration: TextDecoration.underline,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _AudioAttachmentChip extends ConsumerStatefulWidget {
  final Attachment attachment;

  const _AudioAttachmentChip({required this.attachment});

  @override
  ConsumerState<_AudioAttachmentChip> createState() =>
      _AudioAttachmentChipState();
}

class _AudioAttachmentChipState extends ConsumerState<_AudioAttachmentChip> {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<void>? _completionSubscription;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _completionSubscription = _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    });
  }

  @override
  void dispose() {
    _completionSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay(String url) async {
    if (_isPlaying) {
      await _player.stop();
      if (mounted) setState(() => _isPlaying = false);
      return;
    }

    await _player.play(UrlSource(url));
    if (mounted) setState(() => _isPlaying = true);
  }

  @override
  Widget build(BuildContext context) {
    final urlAsync = ref.watch(
      attachmentSignedUrlProvider(widget.attachment.storagePath),
    );

    return urlAsync.when(
      data: (url) => Semantics(
        button: true,
        label: _isPlaying ? '오디오 일시정지' : '오디오 재생',
        child: InkWell(
          onTap: () => _togglePlay(url),
          borderRadius: BorderRadius.circular(4),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF242424),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF333333)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: const Color(0xFF9A9A9A),
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.attachment.filename ?? '오디오',
                      style: const TextStyle(
                        color: Color(0xFF9A9A9A),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      loading: () => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF242424),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF333333)),
        ),
        child: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (error, stack) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF242424),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF333333)),
        ),
        child: const Icon(
          Icons.error_outline,
          color: Color(0xFF9A9A9A),
          size: 16,
        ),
      ),
    );
  }
}
