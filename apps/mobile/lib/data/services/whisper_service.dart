import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drop_mobile/core/config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide MultipartFile;

/// Audio transcription service (Supabase Edge Function -> Whisper)
class WhisperService {
  /// Whisper API upload limit (25MB)
  static const int maxFileSizeBytes = 25 * 1024 * 1024;

  static const Duration _connectTimeout = Duration(seconds: 15);
  static const Duration _receiveTimeout = Duration(seconds: 120);

  final Dio _dio;
  final String _endpoint;
  final SupabaseClient _supabase;

  WhisperService({
    Dio? dio,
    String? endpoint,
    SupabaseClient? supabase,
  })  : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: _connectTimeout,
              receiveTimeout: _receiveTimeout,
            )),
        _supabase = supabase ?? Supabase.instance.client,
        _endpoint =
            endpoint ?? '${SupabaseConfig.url}/functions/v1/transcribe';

  /// Transcribe audio file to text
  Future<String> transcribe({
    required String audioPath,
    String? language,
    int retryCount = 3,
  }) async {
    final file = File(audioPath);
    if (!file.existsSync()) {
      throw WhisperException.fileNotFound();
    }

    final fileSize = file.lengthSync();
    if (fileSize > maxFileSizeBytes) {
      throw WhisperException.fileTooLarge(fileSize);
    }

    WhisperException? lastError;

    for (var attempt = 0; attempt < retryCount; attempt++) {
      try {
        return await _performTranscription(audioPath, language);
      } on WhisperException catch (e) {
        if (e.type == WhisperErrorType.rateLimited ||
            e.type == WhisperErrorType.serverError) {
          lastError = e;
          // Exponential backoff (마지막 시도 후에는 대기하지 않음)
          if (attempt < retryCount - 1) {
            final delay = Duration(seconds: 1 << attempt);
            await Future.delayed(delay);
          }
        } else {
          rethrow;
        }
      }
    }

    throw lastError ?? WhisperException.networkError('Unknown error');
  }

  Future<String> _performTranscription(String audioPath, String? language) async {
    final accessToken = _supabase.auth.currentSession?.accessToken;
    if (accessToken == null) {
      throw WhisperException.notAuthenticated();
    }

    final formData = FormData.fromMap({
      if (language != null) 'language': language,
      'file': await MultipartFile.fromFile(
        audioPath,
        filename: 'audio.m4a',
        contentType: DioMediaType('audio', 'm4a'),
      ),
    });

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _endpoint,
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
        ),
      );

      final data = response.data;
      if (data != null && data.containsKey('text')) {
        return data['text'] as String;
      }
      throw WhisperException.decodingError();
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;

      if (statusCode == 401) {
        throw WhisperException.notAuthenticated();
      } else if (statusCode == 429) {
        throw WhisperException.rateLimited();
      } else if (statusCode != null && statusCode >= 500) {
        throw WhisperException.serverError(statusCode);
      }

      // Try to parse error message from response
      final data = e.response?.data;
      if (data is Map<String, dynamic> && data.containsKey('error')) {
        final error = data['error'];
        final message = error is Map<String, dynamic>
            ? error['message'] as String?
            : error?.toString();
        throw WhisperException.apiError(message ?? 'Unknown error');
      }

      throw WhisperException.networkError(e.message ?? 'Network error');
    }
  }
}

enum WhisperErrorType {
  invalidUrl,
  notAuthenticated,
  fileNotFound,
  fileTooLarge,
  networkError,
  apiError,
  decodingError,
  rateLimited,
  serverError,
}

class WhisperException implements Exception {
  final WhisperErrorType type;
  final String message;
  final int? statusCode;

  WhisperException._({
    required this.type,
    required this.message,
    this.statusCode,
  });

  factory WhisperException.invalidUrl() => WhisperException._(
        type: WhisperErrorType.invalidUrl,
        message: 'Invalid API URL',
      );

  factory WhisperException.notAuthenticated() => WhisperException._(
        type: WhisperErrorType.notAuthenticated,
        message: 'Not authenticated. Please sign in and try again.',
        statusCode: 401,
      );

  factory WhisperException.fileNotFound() => WhisperException._(
        type: WhisperErrorType.fileNotFound,
        message: 'Audio file not found',
      );

  factory WhisperException.fileTooLarge(int sizeBytes) => WhisperException._(
        type: WhisperErrorType.fileTooLarge,
        message:
            'Audio file too large (${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB). '
            'Maximum allowed size is 25MB.',
      );

  factory WhisperException.networkError(String detail) => WhisperException._(
        type: WhisperErrorType.networkError,
        message: 'Network error: $detail',
      );

  factory WhisperException.apiError(String detail) => WhisperException._(
        type: WhisperErrorType.apiError,
        message: 'API error: $detail',
      );

  factory WhisperException.decodingError() => WhisperException._(
        type: WhisperErrorType.decodingError,
        message: 'Failed to decode response',
      );

  factory WhisperException.rateLimited() => WhisperException._(
        type: WhisperErrorType.rateLimited,
        message: 'Rate limited. Please try again later.',
      );

  factory WhisperException.serverError(int code) => WhisperException._(
        type: WhisperErrorType.serverError,
        message: 'Server error (code: $code)',
        statusCode: code,
      );

  @override
  String toString() => message;
}
