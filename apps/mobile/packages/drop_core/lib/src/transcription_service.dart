/// Whisper 전사. DropCore `TranscriptionService.swift` 대응.
///
/// 정책은 그대로 둔다: 25MB 상한 · 3회 시도 · 429/5xx만 지수 백오프(1s, 2s) ·
/// 마지막 시도 뒤에는 기다리지 않는다.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

sealed class TranscriptionError implements Exception {
  const TranscriptionError();

  const factory TranscriptionError.fileNotFound() = TranscriptionFileNotFound;
  const factory TranscriptionError.fileTooLarge(int size) =
      TranscriptionFileTooLarge;
  const factory TranscriptionError.rateLimited() = TranscriptionRateLimited;
  const factory TranscriptionError.serverError(int statusCode) =
      TranscriptionServerError;
  const factory TranscriptionError.rejected(int statusCode) =
      TranscriptionRejected;
  const factory TranscriptionError.network(String message) =
      TranscriptionNetworkError;
  const factory TranscriptionError.malformedResponse() =
      TranscriptionMalformedResponse;
}

class TranscriptionFileNotFound extends TranscriptionError {
  const TranscriptionFileNotFound();

  @override
  bool operator ==(Object other) => other is TranscriptionFileNotFound;

  @override
  int get hashCode => (TranscriptionFileNotFound).hashCode;
}

class TranscriptionFileTooLarge extends TranscriptionError {
  final int size;

  const TranscriptionFileTooLarge(this.size);

  @override
  bool operator ==(Object other) =>
      other is TranscriptionFileTooLarge && other.size == size;

  @override
  int get hashCode => size.hashCode;
}

class TranscriptionRateLimited extends TranscriptionError {
  const TranscriptionRateLimited();

  @override
  bool operator ==(Object other) => other is TranscriptionRateLimited;

  @override
  int get hashCode => (TranscriptionRateLimited).hashCode;
}

class TranscriptionServerError extends TranscriptionError {
  final int statusCode;

  const TranscriptionServerError(this.statusCode);

  @override
  bool operator ==(Object other) =>
      other is TranscriptionServerError && other.statusCode == statusCode;

  @override
  int get hashCode => statusCode.hashCode;
}

class TranscriptionRejected extends TranscriptionError {
  final int statusCode;

  const TranscriptionRejected(this.statusCode);

  @override
  bool operator ==(Object other) =>
      other is TranscriptionRejected && other.statusCode == statusCode;

  @override
  int get hashCode => statusCode.hashCode;
}

class TranscriptionNetworkError extends TranscriptionError {
  final String message;

  const TranscriptionNetworkError(this.message);

  @override
  bool operator ==(Object other) =>
      other is TranscriptionNetworkError && other.message == message;

  @override
  int get hashCode => message.hashCode;
}

class TranscriptionMalformedResponse extends TranscriptionError {
  const TranscriptionMalformedResponse();

  @override
  bool operator ==(Object other) => other is TranscriptionMalformedResponse;

  @override
  int get hashCode => (TranscriptionMalformedResponse).hashCode;
}

abstract interface class TranscriptionService {
  Future<String> transcribe(String audioPath, {String? language});
}

class SupabaseTranscriptionService implements TranscriptionService {
  static const maxFileSizeBytes = 25 * 1024 * 1024;
  static const _attemptLimit = 3;

  final Uri endpoint;
  final String? Function() authorizationToken;
  final http.Client httpClient;
  final Future<void> Function(Duration) sleep;

  SupabaseTranscriptionService({
    required this.endpoint,
    required this.authorizationToken,
    required this.httpClient,
    Future<void> Function(Duration)? sleep,
  }) : sleep = sleep ?? Future<void>.delayed;

  @override
  Future<String> transcribe(String audioPath, {String? language}) async {
    final file = File(audioPath);
    if (!file.existsSync()) {
      throw const TranscriptionError.fileNotFound();
    }

    final size = file.lengthSync();
    // 올리고 나서 거절당하면 사용자는 그 업로드 시간만큼 헛되이 기다린다.
    if (size > maxFileSizeBytes) {
      throw TranscriptionError.fileTooLarge(size);
    }

    final data = file.readAsBytesSync();
    final fileName = audioPath.split(Platform.pathSeparator).last;
    TranscriptionError lastError =
        const TranscriptionError.network('시도하지 못했습니다');

    for (var attempt = 0; attempt < _attemptLimit; attempt += 1) {
      try {
        return await _send(data: data, fileName: fileName, language: language);
      } on TranscriptionError catch (error) {
        if (!_isRetryable(error)) rethrow;
        lastError = error;
        // 마지막 시도 뒤에는 기다리지 않는다 — 기다려도 할 일이 없다.
        if (attempt < _attemptLimit - 1) {
          await sleep(Duration(seconds: 1 << attempt));
        }
      }
    }
    throw lastError;
  }

  static bool _isRetryable(TranscriptionError error) => switch (error) {
        TranscriptionRateLimited() ||
        TranscriptionServerError() ||
        TranscriptionNetworkError() =>
          true,
        _ => false,
      };

  Future<String> _send({
    required List<int> data,
    required String fileName,
    required String? language,
  }) async {
    final boundary = 'drop-${Random().nextInt(1 << 32)}';
    final headers = {
      'Content-Type': 'multipart/form-data; boundary=$boundary',
    };
    final token = authorizationToken();
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    final http.Response response;
    try {
      response = await httpClient.post(
        endpoint,
        headers: headers,
        body: _multipartBody(
          boundary: boundary,
          data: data,
          fileName: fileName,
          language: language,
        ),
      );
    } on TranscriptionError {
      rethrow;
    } catch (error) {
      throw TranscriptionError.network(error.toString());
    }

    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      try {
        final json = jsonDecode(utf8.decode(response.bodyBytes));
        final text = (json as Map)['text'];
        if (text is String) return text;
      } catch (_) {}
      throw const TranscriptionError.malformedResponse();
    }
    if (status == 429) throw const TranscriptionError.rateLimited();
    if (status >= 500) throw TranscriptionError.serverError(status);
    throw TranscriptionError.rejected(status);
  }

  static List<int> _multipartBody({
    required String boundary,
    required List<int> data,
    required String fileName,
    required String? language,
  }) {
    final body = <int>[];
    void append(String string) => body.addAll(utf8.encode(string));

    append('--$boundary\r\n');
    append('Content-Disposition: form-data; name="file"; filename="$fileName"\r\n');
    append('Content-Type: audio/m4a\r\n\r\n');
    body.addAll(data);
    append('\r\n');

    if (language != null) {
      append('--$boundary\r\n');
      append('Content-Disposition: form-data; name="language"\r\n\r\n');
      append('$language\r\n');
    }

    append('--$boundary--\r\n');
    return body;
  }
}
