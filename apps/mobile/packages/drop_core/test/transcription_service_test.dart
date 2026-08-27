import 'dart:convert';
import 'dart:io';

import 'package:drop_core/drop_core.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// DropCore `TranscriptionServiceTests.swift` 포팅.
/// `whisper` 전사 정책 검증 — 재시도·크기 제한이 조용히 어긋나면
/// 요금과 사용자 대기 시간으로 돌아온다.
void main() {
  http.Response json(int status, String body) => http.Response.bytes(
        utf8.encode(body),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  (SupabaseTranscriptionService, List<http.Request>) makeService(
    http.Response Function(http.Request, int requestCount) responder,
  ) {
    final requests = <http.Request>[];
    final service = SupabaseTranscriptionService(
      endpoint: Uri.parse('https://stub.supabase.co/functions/v1/transcribe'),
      authorizationToken: () => 'token',
      httpClient: MockClient((request) async {
        requests.add(request);
        return responder(request, requests.length);
      }),
      // 테스트에서 실제로 기다리지 않도록 대기를 가로챈다.
      sleep: (_) async {},
    );
    return (service, requests);
  }

  String audioFile(int bytes) {
    final file = File(
        '${Directory.systemTemp.path}/drop-core-test-${DateTime.now().microsecondsSinceEpoch}-$bytes.m4a');
    file.writeAsBytesSync(List.filled(bytes, 0));
    addTearDown(() {
      if (file.existsSync()) file.deleteSync();
    });
    return file.path;
  }

  group('Whisper 전사', () {
    test('전사 결과 텍스트를 돌려준다', () async {
      final (service, _) = makeService((_, _) => json(200, '{"text":"안녕하세요"}'));

      final text = await service.transcribe(audioFile(100));

      expect(text, '안녕하세요');
    });

    /// Whisper 업로드 상한은 25MB. 넘으면 **요청을 보내기 전에** 실패해야 한다 —
    /// 올리고 나서 거절당하면 사용자는 그 시간만큼 기다린다.
    test('25MB를 넘으면 올리지 않고 실패한다', () async {
      final (service, requests) =
          makeService((_, _) => json(200, '{"text":""}'));
      final file = audioFile(25 * 1024 * 1024 + 1);

      await expectLater(
        service.transcribe(file),
        throwsA(const TranscriptionError.fileTooLarge(25 * 1024 * 1024 + 1)),
      );
      expect(requests, isEmpty);
    });

    test('파일이 없으면 명확히 실패한다', () async {
      final (service, _) = makeService((_, _) => json(200, ''));

      await expectLater(
        service.transcribe('/없는/경로.m4a'),
        throwsA(const TranscriptionError.fileNotFound()),
      );
    });

    /// 429/5xx만 재시도한다. 총 3회 시도 후 포기.
    test('속도 제한이면 세 번까지 다시 시도한다', () async {
      final (service, requests) =
          makeService((_, _) => json(429, '{"error":"rate limited"}'));

      await expectLater(
        service.transcribe(audioFile(10)),
        throwsA(isA<TranscriptionError>()),
      );
      expect(requests.length, 3);
    });

    test('서버 오류도 재시도 대상이다', () async {
      final (service, requests) =
          makeService((_, _) => json(500, '{"error":"boom"}'));

      await expectLater(
        service.transcribe(audioFile(10)),
        throwsA(isA<TranscriptionError>()),
      );
      expect(requests.length, 3);
    });

    /// 잘못된 요청은 다시 보내 봐야 같은 답이 온다. 재시도하면 시간만 버린다.
    test('400은 재시도하지 않는다', () async {
      final (service, requests) =
          makeService((_, _) => json(400, '{"error":"bad"}'));

      await expectLater(
        service.transcribe(audioFile(10)),
        throwsA(isA<TranscriptionError>()),
      );
      expect(requests.length, 1);
    });

    test('재시도 도중 성공하면 그 결과를 쓴다', () async {
      final (service, requests) = makeService((_, count) => count == 1
          ? json(503, '{"error":"busy"}')
          : json(200, '{"text":"두 번째에 성공"}'));

      final text = await service.transcribe(audioFile(10));

      expect(text, '두 번째에 성공');
      expect(requests.length, 2);
    });

    test('multipart 본문과 인증 헤더를 붙여 보낸다', () async {
      final (service, requests) =
          makeService((_, _) => json(200, '{"text":"ok"}'));

      await service.transcribe(audioFile(10));

      final request = requests.single;
      expect(request.headers['Authorization'], 'Bearer token');
      expect(
        request.headers['Content-Type'],
        startsWith('multipart/form-data'),
      );
    });
  });
}
