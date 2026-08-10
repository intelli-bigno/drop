import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drop_mobile/data/models/models.dart';
import 'package:drop_mobile/presentation/providers/books_provider.dart';
import 'package:drop_mobile/presentation/widgets/book_card.dart';

/// Section widget to display books linked to a note
class LinkedBooksSection extends ConsumerWidget {
  final String noteId;
  final bool editable;
  final VoidCallback? onAddBook;

  const LinkedBooksSection({
    super.key,
    required this.noteId,
    this.editable = false,
    this.onAddBook,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linkedBooksAsync = ref.watch(linkedBooksProvider(noteId));

    return linkedBooksAsync.when(
      data: (books) {
        if (books.isEmpty && !editable) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFF333333))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.book_outlined,
                        color: Color(0xFF9A9A9A),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '연결된 책 (${books.length})',
                        style: const TextStyle(
                          color: Color(0xFF9A9A9A),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  if (editable && onAddBook != null)
                    GestureDetector(
                      onTap: onAddBook,
                      child: const Icon(
                        Icons.add,
                        color: Color(0xFF4A9EFF),
                        size: 18,
                      ),
                    ),
                ],
              ),
              if (books.isNotEmpty) ...[
                const SizedBox(height: 8),
                // Horizontal scrollable book list
                SizedBox(
                  height: 110,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: books.length,
                    itemBuilder: (context, index) {
                      final book = books[index];
                      return LinkedBookCard(
                        book: book,
                        onRemove: editable
                            ? () => _unlinkBook(ref, book)
                            : null,
                      );
                    },
                  ),
                ),
              ] else if (editable) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: onAddBook,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF333333),
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: const Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.add_circle_outline,
                            color: Color(0xFF666666),
                            size: 24,
                          ),
                          SizedBox(height: 4),
                          Text(
                            '책 연결하기',
                            style: TextStyle(
                              color: Color(0xFF666666),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(12),
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (error, stack) => Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          '책 로드 실패',
          style: TextStyle(color: Colors.red[300], fontSize: 12),
        ),
      ),
    );
  }

  void _unlinkBook(WidgetRef ref, Book book) {
    ref.read(booksProvider.notifier).unlinkBookFromNote(
          book.id,
          noteId,
        );
    // Invalidate to refresh the list
    ref.invalidate(linkedBooksProvider(noteId));
  }
}

/// Inline chips for displaying linked books in compact view
class LinkedBooksChips extends ConsumerWidget {
  final String noteId;

  const LinkedBooksChips({
    super.key,
    required this.noteId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linkedBooksAsync = ref.watch(linkedBooksProvider(noteId));

    return linkedBooksAsync.when(
      data: (books) {
        if (books.isEmpty) return const SizedBox.shrink();

        return Wrap(
          spacing: 4,
          runSpacing: 4,
          children: books.take(3).map((book) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF242424),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFF333333)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.book,
                    color: Color(0xFF666666),
                    size: 10,
                  ),
                  const SizedBox(width: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 80),
                    child: Text(
                      book.title,
                      style: const TextStyle(
                        color: Color(0xFF9A9A9A),
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
