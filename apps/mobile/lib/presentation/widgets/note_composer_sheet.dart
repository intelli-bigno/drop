import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:drop_mobile/data/models/models.dart';
import 'package:drop_mobile/data/repositories/attachments_repository.dart';
import 'package:drop_mobile/presentation/providers/notes_provider.dart';
import 'package:drop_mobile/presentation/providers/tags_provider.dart';

class NoteComposerSheet extends ConsumerStatefulWidget {
  final Note? note;
  final String? parentId;
  final List<SharedMediaFile>? sharedMedia;
  final String? sharedText;

  const NoteComposerSheet({
    super.key,
    this.note,
    this.parentId,
    this.sharedMedia,
    this.sharedText,
  });

  @override
  ConsumerState<NoteComposerSheet> createState() => _NoteComposerSheetState();
}

class _NoteComposerSheetState extends ConsumerState<NoteComposerSheet> {
  late final TextEditingController _controller;
  final ImagePicker _imagePicker = ImagePicker();
  bool _isSaving = false;
  List<SharedMediaFile> _pendingMedia = [];
  List<String> _selectedTagNames = [];

  bool get _isEditing => widget.note != null;
  bool get _hasSharedContent =>
      widget.sharedMedia != null || widget.sharedText != null;

  @override
  void initState() {
    super.initState();
    // Initialize with shared text or existing note content
    String initialText = widget.note?.content ?? '';
    if (widget.sharedText != null && widget.sharedText!.isNotEmpty) {
      initialText = widget.sharedText!;
    }
    _controller = TextEditingController(text: initialText);

    // Initialize pending media
    if (widget.sharedMedia != null) {
      _pendingMedia = List.from(widget.sharedMedia!);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _removeMedia(int index) {
    setState(() {
      _pendingMedia.removeAt(index);
    });
  }

  Future<void> _pickFromCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _pendingMedia.add(
            SharedMediaFile(path: image.path, type: SharedMediaType.image),
          );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('카메라에 접근할 수 없습니다')));
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage(
        imageQuality: 85,
      );
      if (images.isNotEmpty) {
        setState(() {
          for (final image in images) {
            _pendingMedia.add(
              SharedMediaFile(path: image.path, type: SharedMediaType.image),
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('갤러리에 접근할 수 없습니다')));
      }
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;

    final content = _controller.text.trimRight();
    final hasMedia = _pendingMedia.isNotEmpty;
    final canSave = _isEditing || content.trim().isNotEmpty || hasMedia;
    if (!canSave) return;

    setState(() => _isSaving = true);

    try {
      if (_isEditing) {
        await ref
            .read(notesProvider.notifier)
            .updateNote(widget.note!.id, content);
      } else {
        // Create note first
        final note = await ref
            .read(notesProvider.notifier)
            .createNote(content: content, parentId: widget.parentId);

        // Upload attachments
        final attachmentsRepo = ref.read(attachmentsRepositoryProvider);
        for (final media in _pendingMedia) {
          try {
            final file = File(media.path);
            if (!await file.exists()) continue;

            switch (media.type) {
              case SharedMediaType.image:
                final attachment = await attachmentsRepo.createImageAttachment(
                  noteId: note.id,
                  file: file,
                );
                ref
                    .read(notesProvider.notifier)
                    .addAttachmentToNote(note.id, attachment);
                break;
              case SharedMediaType.video:
                final attachment = await attachmentsRepo.createFileAttachment(
                  noteId: note.id,
                  file: file,
                  type: 'video',
                );
                ref
                    .read(notesProvider.notifier)
                    .addAttachmentToNote(note.id, attachment);
                break;
              case SharedMediaType.file:
                final attachment = await attachmentsRepo.createFileAttachment(
                  noteId: note.id,
                  file: file,
                  type: 'file',
                );
                ref
                    .read(notesProvider.notifier)
                    .addAttachmentToNote(note.id, attachment);
                break;
              case SharedMediaType.text:
              case SharedMediaType.url:
                // Text and URL are handled as note content, not attachments
                break;
            }
          } catch (e) {
            debugPrint('Failed to upload attachment: $e');
          }
        }

        // Add selected tags to the note
        for (final tagName in _selectedTagNames) {
          try {
            await ref
                .read(tagsProvider.notifier)
                .addTagToNote(note.id, tagName);
          } catch (e) {
            debugPrint('Failed to add tag: $e');
          }
        }
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('저장에 실패했습니다')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _controller.text.trim();
    final hasMedia = _pendingMedia.isNotEmpty;
    final canSave = _isEditing || content.isNotEmpty || hasMedia;

    String title = '새 노트';
    if (_isEditing) {
      title = '노트 편집';
    } else if (_hasSharedContent) {
      title = 'DROP에 저장';
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF3A3A3A),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          // Media preview
          if (_pendingMedia.isNotEmpty) ...[
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _pendingMedia.length,
                itemBuilder: (context, index) {
                  final media = _pendingMedia[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _buildMediaPreview(media),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _removeMedia(index),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],

          TextField(
            controller: _controller,
            maxLines: 8,
            minLines: 4,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: '내용을 입력하세요',
              hintStyle: TextStyle(color: Color(0xFF666666)),
              filled: true,
              fillColor: Color(0xFF232323),
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          // Media picker buttons (only show when not editing)
          if (!_isEditing) ...[
            Row(
              children: [
                _buildMediaButton(
                  icon: Icons.camera_alt,
                  label: '카메라',
                  onPressed: _isSaving ? null : _pickFromCamera,
                ),
                const SizedBox(width: 12),
                _buildMediaButton(
                  icon: Icons.photo_library,
                  label: '갤러리',
                  onPressed: _isSaving ? null : _pickFromGallery,
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 12),
            // Tag selection (only show when creating new note)
            _buildTagSelector(),
            const SizedBox(height: 12),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _isSaving ? null : () => Navigator.pop(context),
                child: const Text('취소'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isSaving || !canSave ? null : _save,
                child: Text(_isSaving ? '저장 중...' : '저장'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTagSelector() {
    return GestureDetector(
      onTap: _isSaving ? null : _showTagSelectorSheet,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.label_outline,
              size: 20,
              color: _isSaving ? Colors.grey : Colors.white70,
            ),
            const SizedBox(width: 8),
            if (_selectedTagNames.isEmpty)
              Text(
                '태그 추가',
                style: TextStyle(
                  color: _isSaving ? Colors.grey : Colors.white70,
                  fontSize: 14,
                ),
              )
            else
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _selectedTagNames.map((tagName) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A9EFF).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '#$tagName',
                            style: const TextStyle(
                              color: Color(0xFF4A9EFF),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedTagNames.remove(tagName);
                              });
                            },
                            child: const Icon(
                              Icons.close,
                              size: 14,
                              color: Color(0xFF4A9EFF),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            if (_selectedTagNames.isEmpty)
              const Spacer(),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: _isSaving ? Colors.grey : Colors.white54,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTagSelectorSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _TagSelectorSheet(
        selectedTagNames: _selectedTagNames,
        onTagsChanged: (tags) {
          setState(() {
            _selectedTagNames = tags;
          });
        },
      ),
    );
  }

  Widget _buildMediaButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return Material(
      color: const Color(0xFF2A2A2A),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: onPressed == null ? Colors.grey : Colors.white70,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: onPressed == null ? Colors.grey : Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaPreview(SharedMediaFile media) {
    switch (media.type) {
      case SharedMediaType.image:
        final file = File(media.path);
        if (file.existsSync()) {
          return Image.file(file, width: 100, height: 100, fit: BoxFit.cover);
        }
        return _buildPlaceholder(Icons.image);
      case SharedMediaType.video:
        if (media.thumbnail != null) {
          final thumbFile = File(media.thumbnail!);
          if (thumbFile.existsSync()) {
            return Stack(
              alignment: Alignment.center,
              children: [
                Image.file(
                  thumbFile,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                ),
                const Icon(
                  Icons.play_circle_outline,
                  color: Colors.white,
                  size: 32,
                ),
              ],
            );
          }
        }
        return _buildPlaceholder(Icons.videocam);
      case SharedMediaType.file:
        return _buildPlaceholder(Icons.insert_drive_file);
      case SharedMediaType.text:
        return _buildPlaceholder(Icons.text_fields);
      case SharedMediaType.url:
        return _buildPlaceholder(Icons.link);
    }
  }

  Widget _buildPlaceholder(IconData icon) {
    return Container(
      width: 100,
      height: 100,
      color: const Color(0xFF2A2A2A),
      child: Icon(icon, color: Colors.grey, size: 32),
    );
  }
}

/// Tag selector sheet widget
class _TagSelectorSheet extends ConsumerStatefulWidget {
  final List<String> selectedTagNames;
  final ValueChanged<List<String>> onTagsChanged;

  const _TagSelectorSheet({
    required this.selectedTagNames,
    required this.onTagsChanged,
  });

  @override
  ConsumerState<_TagSelectorSheet> createState() => _TagSelectorSheetState();
}

class _TagSelectorSheetState extends ConsumerState<_TagSelectorSheet> {
  late List<String> _localSelectedTags;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _localSelectedTags = List.from(widget.selectedTagNames);
    // Auto-focus the search input after sheet is shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _toggleTag(String tagName) {
    setState(() {
      final normalizedName = tagName.trim().toLowerCase();
      if (_localSelectedTags.contains(normalizedName)) {
        _localSelectedTags.remove(normalizedName);
      } else {
        _localSelectedTags.add(normalizedName);
      }
    });
    widget.onTagsChanged(_localSelectedTags);
  }

  void _createAndSelectTag(String tagName) {
    final normalizedName = tagName.trim().toLowerCase();
    if (normalizedName.isEmpty) return;
    if (_localSelectedTags.contains(normalizedName)) return;

    setState(() {
      _localSelectedTags.add(normalizedName);
      _searchController.clear();
      _searchQuery = '';
    });
    widget.onTagsChanged(_localSelectedTags);
  }

  @override
  Widget build(BuildContext context) {
    final allTags = ref.watch(allTagsProvider);
    final trimmedQuery = _searchQuery.trim().toLowerCase();

    // Filter tags by search query
    final filteredTags = trimmedQuery.isEmpty
        ? allTags
        : allTags
            .where((t) => t.name.toLowerCase().contains(trimmedQuery))
            .toList();

    // Check if we should show "create new tag" option
    final exactMatch = allTags.any((t) => t.name.toLowerCase() == trimmedQuery);
    final showCreateOption = trimmedQuery.isNotEmpty && !exactMatch;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF3A3A3A),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          // Title
          const Text(
            '태그 선택',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          // Selected tags
          if (_localSelectedTags.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF232323),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _localSelectedTags.map((tagName) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A9EFF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '#$tagName',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => _toggleTag(tagName),
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
          ],
          // Search input
          TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            onChanged: (value) => setState(() => _searchQuery = value),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: '태그 검색 또는 생성...',
              hintStyle: const TextStyle(color: Color(0xFF666666)),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF666666)),
              filled: true,
              fillColor: const Color(0xFF232323),
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            onSubmitted: (value) {
              if (showCreateOption) {
                _createAndSelectTag(trimmedQuery);
              }
            },
          ),
          const SizedBox(height: 12),
          // Tag list
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 250),
            child: ListView(
              shrinkWrap: true,
              children: [
                // Create new tag option
                if (showCreateOption)
                  _buildTagItem(
                    isCreate: true,
                    tagName: trimmedQuery,
                    isSelected: false,
                    onTap: () => _createAndSelectTag(trimmedQuery),
                  ),
                // Existing tags
                ...filteredTags.map((tag) {
                  final isSelected = _localSelectedTags.contains(tag.name);
                  return _buildTagItem(
                    isCreate: false,
                    tagName: tag.name,
                    isSelected: isSelected,
                    onTap: () => _toggleTag(tag.name),
                  );
                }),
                // Empty state
                if (filteredTags.isEmpty && !showCreateOption)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        '태그가 없습니다',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Done button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('완료'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagItem({
    required bool isCreate,
    required String tagName,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF4A9EFF).withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            if (isCreate)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFF4A9EFF).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.add,
                  size: 16,
                  color: Color(0xFF4A9EFF),
                ),
              )
            else
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF4A9EFF)
                      : const Color(0xFF3A3A3A),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        size: 16,
                        color: Colors.white,
                      )
                    : const Center(
                        child: Text(
                          '#',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ),
            const SizedBox(width: 12),
            if (isCreate)
              RichText(
                text: TextSpan(
                  children: [
                    const TextSpan(
                      text: '"',
                      style: TextStyle(color: Colors.grey),
                    ),
                    TextSpan(
                      text: tagName,
                      style: const TextStyle(
                        color: Color(0xFF4A9EFF),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const TextSpan(
                      text: '" 태그 만들기',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              )
            else
              Text(
                tagName,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF4A9EFF) : Colors.white,
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
