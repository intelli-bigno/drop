import 'package:drop_core/drop_core.dart';
import 'package:test/test.dart';

/// DropCore `DropConfigurationTests.swift` 포팅.
/// 구성값은 빌드 설정 → Map → 런타임 순으로 흘러온다.
/// 읽는 부분을 Map 하나로 좁혀 두어 플랫폼 없이 테스트한다.
void main() {
  const validValues = <String, Object?>{
    'SUPABASE_URL': 'https://abcdefgh.supabase.co',
    'SUPABASE_ANON_KEY': 'anon-key-value',
    'DROP_ENVIRONMENT': 'remote',
    'GOOGLE_WEB_CLIENT_ID': 'web-client.apps.googleusercontent.com',
    'GOOGLE_IOS_CLIENT_ID': 'ios-client.apps.googleusercontent.com',
  };

  group('빌드 구성 로딩', () {
    test('구성 Map으로 구성을 만든다', () {
      final config = DropConfiguration.fromMap(validValues);

      expect(config.supabaseUrl, Uri.parse('https://abcdefgh.supabase.co'));
      expect(config.supabaseAnonKey, 'anon-key-value');
      expect(config.environment, DropEnvironment.remote);
      expect(config.googleWebClientId, 'web-client.apps.googleusercontent.com');
      expect(config.googleIosClientId, 'ios-client.apps.googleusercontent.com');
    });

    /// 웹 클라이언트 ID(serverClientId)를 빠뜨리면 id_token의 audience가
    /// 플랫폼 클라이언트 ID가 되어 Supabase가 `Unacceptable audience`로 거부한다.
    /// 런타임에 로그인 실패로 드러나기 전에 여기서 끊는다.
    test('웹 클라이언트 ID가 없으면 실행 전에 실패한다', () {
      final values = {...validValues}..remove('GOOGLE_WEB_CLIENT_ID');

      expect(
        () => DropConfiguration.fromMap(values),
        throwsA(const DropConfigurationError.missingValue('GOOGLE_WEB_CLIENT_ID')),
      );
    });

    test('iOS 클라이언트 ID가 없으면 실행 전에 실패한다', () {
      final values = {...validValues}..remove('GOOGLE_IOS_CLIENT_ID');

      expect(
        () => DropConfiguration.fromMap(values),
        throwsA(const DropConfigurationError.missingValue('GOOGLE_IOS_CLIENT_ID')),
      );
    });

    /// 두 값이 같다면 웹 클라이언트 ID 자리에 플랫폼 것을 잘못 넣은 것이다.
    /// 이 실수는 정확히 #17에서 겪은 `Unacceptable audience`로 이어진다.
    test('웹·iOS 클라이언트 ID가 같으면 잘못 넣은 것으로 본다', () {
      final values = {
        ...validValues,
        'GOOGLE_WEB_CLIENT_ID': 'ios-client.apps.googleusercontent.com',
      };

      expect(
        () => DropConfiguration.fromMap(values),
        throwsA(const DropConfigurationError.webAndPlatformClientIdsIdentical()),
      );
    });

    test('환경 키가 없으면 localdev로 본다', () {
      final values = {...validValues}..remove('DROP_ENVIRONMENT');

      expect(
        DropConfiguration.fromMap(values).environment,
        DropEnvironment.localdev,
      );
    });

    test('URL이 없으면 명확한 오류를 낸다', () {
      final values = {...validValues}..remove('SUPABASE_URL');

      expect(
        () => DropConfiguration.fromMap(values),
        throwsA(const DropConfigurationError.missingValue('SUPABASE_URL')),
      );
    });

    /// 빌드 설정 값이 비어 있을 때 빈 문자열이 그대로 실린다.
    /// 이걸 통과시키면 런타임에 "왜 인증이 안 되지"로 시간을 날리게 된다.
    test('빈 문자열은 값이 없는 것으로 취급한다', () {
      final values = {...validValues, 'SUPABASE_ANON_KEY': '   '};

      expect(
        () => DropConfiguration.fromMap(values),
        throwsA(const DropConfigurationError.missingValue('SUPABASE_ANON_KEY')),
      );
    });

    test('URL 형식이 아니면 오류를 낸다', () {
      final values = {...validValues, 'SUPABASE_URL': 'not a url'};

      expect(
        () => DropConfiguration.fromMap(values),
        throwsA(const DropConfigurationError.malformedUrl('not a url')),
      );
    });

    /// 빌드 설정이 `//`를 주석으로 해석해 URL의 스킴 구분자가 잘리는 사고가 잦다.
    /// 호스트만 남은 값을 여기서 걸러낸다.
    test('스킴 없는 호스트 값은 오류로 걸러낸다', () {
      final values = {...validValues, 'SUPABASE_URL': 'abcdefgh.supabase.co'};

      expect(
        () => DropConfiguration.fromMap(values),
        throwsA(
            const DropConfigurationError.malformedUrl('abcdefgh.supabase.co')),
      );
    });
  });
}
