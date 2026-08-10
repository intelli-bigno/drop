import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:drop_mobile/data/models/models.dart';
import 'package:drop_mobile/presentation/providers/books_provider.dart';

class BookCard extends ConsumerWidget {
  final Book book;
  final VoidCallback? onTap;
  final bool showActions;

  const BookCard({
    super.key,
    required this.book,
    this.onTap,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardContent = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Book cover
          _buildCover(),
          const SizedBox(width: 12),
          // Book info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  book.title,
                  style: const TextStyle(
                    color: Color(0xFFE0E0E0),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Author
                Text(
                  book.author,
                  style: const TextStyle(
                    color: Color(0xFF9A9A9A),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                // Reading status & rating
                Row(
                  children: [
                    _buildStatusBadge(),
                    if (book.rating != null && book.rating! > 0) ...[
                      const SizedBox(width: 8),
                      _buildRating(book.rating!),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (!showActions) {
      return GestureDetector(
        onTap: onTap,
        child: cardContent,
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Slidable(
        key: ValueKey(book.id),
        endActionPane: ActionPane(
          motion: const BehindMotion(),
          children: [
            SlidableAction(
              onPressed: (_) => _showStatusSheet(context, ref),
              backgroundColor: const Color(0xFF4A9EFF),
              foregroundColor: Colors.white,
              icon: Icons.swap_horiz,
              label: '상태',
            ),
            SlidableAction(
              onPressed: (_) => _confirmDelete(context, ref),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              icon: Icons.delete_outline,
              label: '삭제',
            ),
          ],
        ),
        child: cardContent,
      ),
    );
  }

  Widget _buildCover() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: 60,
        height: 85,
        child: book.coverUrl != null
            ? CachedNetworkImage(
                imageUrl: book.coverUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: const Color(0xFF1A1A1A),
                  child: const Center(
                    child: Icon(Icons.book, color: Color(0xFF444444), size: 24),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: const Color(0xFF1A1A1A),
                  child: const Center(
                    child: Icon(Icons.book, color: Color(0xFF444444), size: 24),
                  ),
                ),
              )
            : Container(
                color: const Color(0xFF1A1A1A),
                child: const Center(
                  child: Icon(Icons.book, color: Color(0xFF444444), size: 24),
                ),
              ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    final (color, text) = switch (book.readingStatus) {
      ReadingStatus.toRead => (const Color(0xFF666666), '읽을예정'),
      ReadingStatus.reading => (const Color(0xFF4A9EFF), '읽는중'),
      ReadingStatus.completed => (const Color(0xFF2E7D32), '완독'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildRating(int rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star : Icons.star_border,
          color: const Color(0xFFFFAA00),
          size: 12,
        );
      }),
    );
  }

  void _showStatusSheet(BuildContext context, WidgetRef ref) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _StatusChangeSheet(
        book: book,
        onStatusChanged: (status, rating) {
          ref.read(booksProvider.notifier).updateReadingStatus(
                book.id,
                status,
                rating: rating,
              );
          Navigator.pop(context);
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('책 삭제', style: TextStyle(color: Colors.white)),
        content: Text(
          '"${book.title}"을(를) 라이브러리에서 삭제하시겠습니까?',
          style: const TextStyle(color: Color(0xFFE0E0E0)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(booksProvider.notifier).deleteBook(book.id);
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _StatusChangeSheet extends StatefulWidget {
  final Book book;
  final void Function(ReadingStatus status, int? rating) onStatusChanged;

  const _StatusChangeSheet({
    required this.book,
    required this.onStatusChanged,
  });

  @override
  State<_StatusChangeSheet> createState() => _StatusChangeSheetState();
}

class _StatusChangeSheetState extends State<_StatusChangeSheet> {
  late ReadingStatus _status;
  int _rating = 0;

  @override
  void initState() {
    super.initState();
    _status = widget.book.readingStatus;
    _rating = widget.book.rating ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.book.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 24),
          const Text(
            '읽기 상태',
            style: TextStyle(color: Color(0xFF9A9A9A), fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildStatusOption(ReadingStatus.toRead, '읽을예정'),
              const SizedBox(width: 8),
              _buildStatusOption(ReadingStatus.reading, '읽는중'),
              const SizedBox(width: 8),
              _buildStatusOption(ReadingStatus.completed, '완독'),
            ],
          ),
          if (_status == ReadingStatus.completed) ...[
            const SizedBox(height: 24),
            const Text(
              '평점',
              style: TextStyle(color: Color(0xFF9A9A9A), fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(5, (index) {
                return GestureDetector(
                  onTap: () => setState(() => _rating = index + 1),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      index < _rating ? Icons.star : Icons.star_border,
                      color: const Color(0xFFFFAA00),
                      size: 32,
                    ),
                  ),
                );
              }),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => widget.onStatusChanged(
                _status,
                _status == ReadingStatus.completed ? _rating : null,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A9EFF),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                '저장',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildStatusOption(ReadingStatus status, String label) {
    final isSelected = _status == status;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _status = status),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF4A9EFF).withValues(alpha: 0.2)
                : const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF4A9EFF)
                  : const Color(0xFF333333),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF4A9EFF) : const Color(0xFF9A9A9A),
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact book card for linked books section
class LinkedBookCard extends StatelessWidget {
  final Book book;
  final VoidCallback? onRemove;

  const LinkedBookCard({
    super.key,
    required this.book,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: 8),
      child: Column(
        children: [
          // Cover with remove button
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  width: 60,
                  height: 85,
                  child: book.coverUrl != null
                      ? CachedNetworkImage(
                          imageUrl: book.coverUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: const Color(0xFF1A1A1A),
                            child: const Center(
                              child: Icon(Icons.book, color: Color(0xFF444444), size: 20),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: const Color(0xFF1A1A1A),
                            child: const Center(
                              child: Icon(Icons.book, color: Color(0xFF444444), size: 20),
                            ),
                          ),
                        )
                      : Container(
                          color: const Color(0xFF1A1A1A),
                          child: const Center(
                            child: Icon(Icons.book, color: Color(0xFF444444), size: 20),
                          ),
                        ),
                ),
              ),
              if (onRemove != null)
                Positioned(
                  top: -4,
                  right: -4,
                  child: GestureDetector(
                    onTap: onRemove,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Color(0xFF333333),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Color(0xFF9A9A9A),
                        size: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          // Title
          Text(
            book.title,
            style: const TextStyle(
              color: Color(0xFFE0E0E0),
              fontSize: 10,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
