import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drop_mobile/data/models/models.dart';
import 'package:drop_mobile/presentation/providers/books_provider.dart';

/// Bottom sheet for linking books to a note
class BookLinkSheet extends ConsumerStatefulWidget {
  final String noteId;
  final List<String> alreadyLinkedBookIds;

  const BookLinkSheet({
    super.key,
    required this.noteId,
    this.alreadyLinkedBookIds = const [],
  });

  @override
  ConsumerState<BookLinkSheet> createState() => _BookLinkSheetState();
}

class _BookLinkSheetState extends ConsumerState<BookLinkSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF444444),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '책 연결',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Color(0xFF9A9A9A)),
                    ),
                  ],
                ),
              ),
              // Tab bar
              TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF4A9EFF),
                labelColor: const Color(0xFF4A9EFF),
                unselectedLabelColor: const Color(0xFF9A9A9A),
                tabs: const [
                  Tab(text: '내 라이브러리'),
                  Tab(text: '책 검색'),
                ],
              ),
              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildLibraryTab(scrollController),
                    _buildSearchTab(scrollController),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLibraryTab(ScrollController scrollController) {
    final booksAsync = ref.watch(booksProvider);

    return booksAsync.when(
      data: (books) {
        // Filter out already linked books
        final availableBooks = books
            .where((b) => !widget.alreadyLinkedBookIds.contains(b.id))
            .toList();

        if (availableBooks.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.book_outlined, color: Color(0xFF444444), size: 48),
                SizedBox(height: 16),
                Text(
                  '연결할 책이 없습니다',
                  style: TextStyle(color: Color(0xFF9A9A9A)),
                ),
                SizedBox(height: 8),
                Text(
                  '책 검색 탭에서 새 책을 추가하세요',
                  style: TextStyle(color: Color(0xFF666666), fontSize: 12),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: availableBooks.length,
          itemBuilder: (context, index) {
            final book = availableBooks[index];
            return _BookLinkItem(
              book: book,
              onLink: () => _linkBook(book),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text(
          '로드 실패: $error',
          style: TextStyle(color: Colors.red[300]),
        ),
      ),
    );
  }

  Widget _buildSearchTab(ScrollController scrollController) {
    final searchState = ref.watch(bookSearchProvider);

    return Column(
      children: [
        // Search input
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: '책 제목, 저자, ISBN으로 검색',
              hintStyle: const TextStyle(color: Color(0xFF666666)),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF666666)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        _searchController.clear();
                        ref.read(bookSearchProvider.notifier).clear();
                      },
                      icon: const Icon(Icons.clear, color: Color(0xFF666666)),
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFF2A2A2A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            onSubmitted: (query) {
              if (query.trim().isNotEmpty) {
                ref.read(bookSearchProvider.notifier).search(query);
              }
            },
          ),
        ),
        // Search results
        Expanded(
          child: searchState.when(
            data: (results) {
              if (results.isEmpty) {
                return const Center(
                  child: Text(
                    '검색어를 입력하세요',
                    style: TextStyle(color: Color(0xFF666666)),
                  ),
                );
              }

              return ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final result = results[index];
                  return _SearchResultItem(
                    result: result,
                    onAdd: () => _addAndLinkBook(result),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '검색 실패',
                    style: TextStyle(color: Colors.red[300]),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      final query = _searchController.text;
                      if (query.trim().isNotEmpty) {
                        ref.read(bookSearchProvider.notifier).search(query);
                      }
                    },
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _linkBook(Book book) async {
    await ref.read(booksProvider.notifier).linkBookToNote(
          book.id,
          widget.noteId,
        );
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _addAndLinkBook(BookSearchResult result) async {
    final book = await ref.read(booksProvider.notifier).addBookFromSearchResult(result);
    if (book != null) {
      await ref.read(booksProvider.notifier).linkBookToNote(
            book.id,
            widget.noteId,
          );
    }
    if (mounted) {
      Navigator.pop(context, true);
    }
  }
}

class _BookLinkItem extends StatelessWidget {
  final Book book;
  final VoidCallback onLink;

  const _BookLinkItem({
    required this.book,
    required this.onLink,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onLink,
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            // Cover
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: 45,
                height: 64,
                child: book.coverUrl != null
                    ? CachedNetworkImage(
                        imageUrl: book.coverUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: const Color(0xFF1A1A1A),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: const Color(0xFF1A1A1A),
                          child: const Icon(Icons.book, color: Color(0xFF444444)),
                        ),
                      )
                    : Container(
                        color: const Color(0xFF1A1A1A),
                        child: const Icon(Icons.book, color: Color(0xFF444444)),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: const TextStyle(
                      color: Color(0xFFE0E0E0),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    book.author,
                    style: const TextStyle(
                      color: Color(0xFF9A9A9A),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Link icon
            const Icon(
              Icons.add_link,
              color: Color(0xFF4A9EFF),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResultItem extends StatelessWidget {
  final BookSearchResult result;
  final VoidCallback onAdd;

  const _SearchResultItem({
    required this.result,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onAdd,
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            // Cover
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: 45,
                height: 64,
                child: result.coverImageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: result.coverImageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: const Color(0xFF1A1A1A),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: const Color(0xFF1A1A1A),
                          child: const Icon(Icons.book, color: Color(0xFF444444)),
                        ),
                      )
                    : Container(
                        color: const Color(0xFF1A1A1A),
                        child: const Icon(Icons.book, color: Color(0xFF444444)),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.title,
                    style: const TextStyle(
                      color: Color(0xFFE0E0E0),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    result.author,
                    style: const TextStyle(
                      color: Color(0xFF9A9A9A),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (result.publisher.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      result.publisher,
                      style: const TextStyle(
                        color: Color(0xFF666666),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // Add icon
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF4A9EFF).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add,
                color: Color(0xFF4A9EFF),
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
