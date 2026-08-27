/// Supabase REST(PostgREST·Storage)에 붙는 최소한의 클라이언트.
///
/// Swift 판은 Supabase SDK를 쓰지만, drop_core는 순수 Dart라 REST 계약을
/// 직접 다룬다. 계약의 정본은 Swift 테스트(InsertPayload·SupabaseNotesRepository)다.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../repository_error.dart';

/// 지금 로그인한 사용자·토큰을 묻는 곳. Flutter 쪽 인증 구현이 채워 준다.
abstract interface class SupabaseSessionProvider {
  /// 로그인한 사용자의 UUID. 없으면 null.
  String? get currentUserId;

  /// Authorization 헤더에 실을 액세스 토큰. 없으면 anon 키를 쓴다.
  String? get accessToken;
}

/// PostgREST/Storage 호출 공통부. 오류를 화면이 다룰 수 있는 형태로 좁힌다.
class SupabaseRestClient {
  final http.Client httpClient;
  final Uri baseUrl;
  final String anonKey;
  final SupabaseSessionProvider session;

  SupabaseRestClient({
    required this.httpClient,
    required this.baseUrl,
    required this.anonKey,
    required this.session,
  });

  Map<String, String> _headers({Map<String, String> extra = const {}}) => {
        'apikey': anonKey,
        'Authorization': 'Bearer ${session.accessToken ?? anonKey}',
        'Content-Type': 'application/json',
        ...extra,
      };

  Uri _restUri(String table, Map<String, String> query) => baseUrl.replace(
        path: '${baseUrl.path}/rest/v1/$table',
        queryParameters: query.isEmpty ? null : query,
      );

  /// GET — 행 배열을 돌려준다.
  Future<List<Object?>> select(String table, Map<String, String> query) =>
      run(() async {
        final response =
            await httpClient.get(_restUri(table, query), headers: _headers());
        return _decodeRows(_check(response));
      });

  /// POST + return=representation — 만들어진 행 하나를 돌려준다.
  Future<Map<String, Object?>> insertReturning(
    String table,
    Map<String, Object?> payload,
  ) =>
      run(() async {
        final response = await httpClient.post(
          _restUri(table, const {}),
          headers: _headers(extra: const {'Prefer': 'return=representation'}),
          body: jsonEncode(payload),
        );
        return _decodeSingle(_check(response));
      });

  /// POST(upsert).
  Future<void> upsert(String table, Map<String, Object?> payload) =>
      run(() async {
        final response = await httpClient.post(
          _restUri(table, const {}),
          headers: _headers(
              extra: const {'Prefer': 'resolution=merge-duplicates'}),
          body: jsonEncode(payload),
        );
        _check(response);
      });

  /// PATCH — 필터에 걸린 행을 고친다.
  Future<void> update(
    String table,
    Map<String, Object?> values, {
    required Map<String, String> filters,
  }) =>
      run(() async {
        final response = await httpClient.patch(
          _restUri(table, filters),
          headers: _headers(),
          body: jsonEncode(values),
        );
        _check(response);
      });

  /// DELETE — 필터에 걸린 행을 지운다.
  Future<void> delete(String table, {required Map<String, String> filters}) =>
      run(() async {
        final response =
            await httpClient.delete(_restUri(table, filters), headers: _headers());
        _check(response);
      });

  // Storage

  Uri _storageUri(String path) =>
      baseUrl.replace(path: '${baseUrl.path}/storage/v1/$path');

  Future<void> storageUpload({
    required String bucket,
    required String path,
    required List<int> data,
    required String contentType,
  }) =>
      run(() async {
        final response = await httpClient.post(
          _storageUri('object/$bucket/$path'),
          headers: _headers(extra: {'Content-Type': contentType}),
          body: data,
        );
        _check(response);
      });

  /// 실패해도 흐름을 막지 않는 정리용 삭제.
  Future<void> storageRemoveQuietly({
    required String bucket,
    required String path,
  }) async {
    try {
      await httpClient.delete(
        _storageUri('object/$bucket/$path'),
        headers: _headers(),
      );
    } catch (_) {
      // 정리 실패는 삼킨다 — 원래 작업의 성패가 우선이다.
    }
  }

  /// 비공개 버킷의 서명 URL.
  Future<Uri> storageSignedUrl({
    required String bucket,
    required String path,
    required int expiresIn,
  }) =>
      run(() async {
        final response = await httpClient.post(
          _storageUri('object/sign/$bucket/$path'),
          headers: _headers(),
          body: jsonEncode({'expiresIn': expiresIn}),
        );
        final json = _decodeSingle(_check(response));
        final signed = (json['signedURL'] ?? json['signedUrl']) as String;
        return baseUrl.replace(
            path: '${baseUrl.path}/storage/v1${signed.split('?').first}',
            query: signed.contains('?') ? signed.split('?').last : null);
      });

  // 내부

  http.Response _check(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    }
    // 서버 거절 — PostgREST는 {"message": ...}를 준다.
    String reason = response.body;
    try {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json is Map && json['message'] is String) {
        reason = json['message'] as String;
      }
    } catch (_) {}
    throw NotesRepositoryError.rejected(reason);
  }

  static List<Object?> _decodeRows(http.Response response) {
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) {
      throw NotesRepositoryError.decoding('배열이 아닌 응답: ${response.body}');
    }
    return decoded;
  }

  static Map<String, Object?> _decodeSingle(http.Response response) {
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is Map<String, Object?>) return decoded;
    if (decoded is List && decoded.isNotEmpty) {
      return (decoded.first as Map).cast<String, Object?>();
    }
    throw NotesRepositoryError.decoding('행 하나를 기대한 응답: ${response.body}');
  }

  /// 오류를 화면이 다룰 수 있는 형태로 좁힌다.
  /// 취소는 그대로 올려 보낸다 — 네트워크 장애로 둔갑하면 안 된다.
  Future<T> run<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on RequestCancelled {
      rethrow;
    } on NotesRepositoryError {
      rethrow;
    } on FormatException catch (error) {
      throw NotesRepositoryError.decoding(error.toString());
    } on TypeError catch (error) {
      throw NotesRepositoryError.decoding(error.toString());
    } catch (error) {
      throw NotesRepositoryError.network(error.toString());
    }
  }

  /// PostgREST `in` 필터 값. `in.("a","b")`
  static String inFilter(Iterable<String> values) =>
      'in.(${values.map((v) => '"$v"').join(',')})';
}
