import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drop_mobile/data/models/models.dart';
import 'package:drop_mobile/presentation/providers/books_provider.dart';
import 'package:drop_mobile/presentation/widgets/book_card.dart';

class BooksScreen extends ConsumerWidget {
  const BooksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(booksProvider);
    final filter = ref.watch(bookFilterProvider);
    final counts = ref.watch(bookCountsProvider);
    final filteredBooks = ref.watch(filteredBooksProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        title: const Text(
          '내 책장',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => context.push('/books/search'),
            icon: const Icon(Icons.add, color: Colors.white),
            tooltip: '책 추가',
          ),
        ],
      ),
      body: booksAsync.when(
        data: (_) => Column(
          children: [
            // Filter chips
            _buildFilterSection(ref, filter, counts),
            // Books list
            Expanded(
              child: filteredBooks.isEmpty
                  ? _buildEmptyState(filter)
                  : RefreshIndicator(
                      onRefresh: () => ref.refresh(booksProvider.future),
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredBooks.length,
                        itemBuilder: (context, index) {
                          final book = filteredBooks[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: BookCard(book: book),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                '로드 실패',
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
                onPressed: () => ref.invalidate(booksProvider),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection(
    WidgetRef ref,
    ReadingStatus? filter,
    Map<ReadingStatus, int> counts,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _FilterChip(
              label: '전체',
              count: counts.values.fold(0, (a, b) => a + b),
              isSelected: filter == null,
              onTap: () {
                HapticFeedback.lightImpact();
                ref.read(bookFilterProvider.notifier).setFilter(null);
              },
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: '읽을예정',
              count: counts[ReadingStatus.toRead] ?? 0,
              isSelected: filter == ReadingStatus.toRead,
              color: const Color(0xFF666666),
              onTap: () {
                HapticFeedback.lightImpact();
                ref.read(bookFilterProvider.notifier).setFilter(ReadingStatus.toRead);
              },
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: '읽는중',
              count: counts[ReadingStatus.reading] ?? 0,
              isSelected: filter == ReadingStatus.reading,
              color: const Color(0xFF4A9EFF),
              onTap: () {
                HapticFeedback.lightImpact();
                ref.read(bookFilterProvider.notifier).setFilter(ReadingStatus.reading);
              },
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: '완독',
              count: counts[ReadingStatus.completed] ?? 0,
              isSelected: filter == ReadingStatus.completed,
              color: const Color(0xFF2E7D32),
              onTap: () {
                HapticFeedback.lightImpact();
                ref.read(bookFilterProvider.notifier).setFilter(ReadingStatus.completed);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ReadingStatus? filter) {
    final (icon, title, subtitle) = switch (filter) {
      null => (
          Icons.library_books_outlined,
          '책장이 비어 있습니다',
          '+ 버튼을 눌러 책을 추가하세요',
        ),
      ReadingStatus.toRead => (
          Icons.bookmark_border,
          '읽을 책이 없습니다',
          '읽고 싶은 책을 추가해보세요',
        ),
      ReadingStatus.reading => (
          Icons.menu_book,
          '읽는 중인 책이 없습니다',
          '책을 읽기 시작하면 여기에 표시됩니다',
        ),
      ReadingStatus.completed => (
          Icons.done_all,
          '완독한 책이 없습니다',
          '책을 완독하면 여기에 표시됩니다',
        ),
    };

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.isSelected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? const Color(0xFF4A9EFF);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? chipColor.withValues(alpha: 0.2)
              : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? chipColor : const Color(0xFF333333),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? chipColor : const Color(0xFF9A9A9A),
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? chipColor.withValues(alpha: 0.3)
                    : const Color(0xFF333333),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  color: isSelected ? chipColor : const Color(0xFF666666),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
