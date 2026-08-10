import 'package:dio/dio.dart';
import 'package:drop_mobile/core/config/supabase_config.dart';
import 'package:drop_mobile/data/models/models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BookSearchService {
  final Dio _dio;
  final SupabaseClient _supabase;
  final String _endpoint;

  BookSearchService({
    Dio? dio,
    SupabaseClient? supabase,
    String? endpoint,
  })  : _dio = dio ?? Dio(),
        _supabase = supabase ?? Supabase.instance.client,
        _endpoint =
            endpoint ?? '${SupabaseConfig.url}/functions/v1/book-search';

  /// Unified book search via the book-search Edge Function
  /// (provider fan-out, dedup, and priority happen server-side)
  Future<List<BookSearchResult>> search(String query) async {
    if (query.trim().isEmpty) return [];

    final accessToken = _supabase.auth.currentSession?.accessToken;
    if (accessToken == null) {
      throw StateError('Not authenticated. Please sign in and try again.');
    }

    final response = await _dio.get<Map<String, dynamic>>(
      _endpoint,
      queryParameters: {'q': query},
      options: Options(headers: {
        'Authorization': 'Bearer $accessToken',
      }),
    );

    final items = response.data?['items'] as List? ?? [];
    return items
        .whereType<Map<String, dynamic>>()
        .map((item) => BookSearchResult(
              isbn13: item['isbn13']?.toString() ?? '',
              isbn10: item['isbn10']?.toString(),
              title: item['title']?.toString() ?? '',
              author: item['author']?.toString() ?? '',
              publisher: item['publisher']?.toString() ?? '',
              pubDate: item['pubDate']?.toString(),
              description: item['description']?.toString(),
              thumbnail: item['coverUrl']?.toString(),
              cover: item['coverUrl']?.toString(),
              source: _parseSource(item['provider']?.toString()),
            ))
        .where((r) => r.isbn13.isNotEmpty)
        .toList();
  }

  BookSearchSource _parseSource(String? provider) {
    return switch (provider) {
      'aladin' => BookSearchSource.aladin,
      'naver' => BookSearchSource.naver,
      'kakao' => BookSearchSource.kakao,
      _ => BookSearchSource.google,
    };
  }
}
