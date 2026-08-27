/// 빌드 구성값. DropCore `DropConfiguration.swift` 대응.
///
/// iOS는 xcconfig → Info.plist, Flutter는 `--dart-define` → Map 순으로 흘러온다.
/// 읽는 지점을 Map 하나로 좁혀 두어, 플랫폼 없이도 테스트할 수 있게 했다.
library;

/// 앱이 어느 Supabase를 보는지.
enum DropEnvironment {
  localdev,
  remote;

  static DropEnvironment? fromRaw(String raw) {
    final trimmed = raw.trim();
    for (final value in DropEnvironment.values) {
      if (value.name == trimmed) return value;
    }
    return null;
  }
}

sealed class DropConfigurationError implements Exception {
  const DropConfigurationError();

  /// 키가 아예 없거나, 공백뿐인 값이 들어왔다.
  const factory DropConfigurationError.missingValue(String key) =
      MissingConfigurationValue;
  const factory DropConfigurationError.malformedUrl(String value) =
      MalformedConfigurationUrl;

  /// 웹 클라이언트 ID 자리에 iOS/Android 클라이언트 ID를 넣은 경우.
  const factory DropConfigurationError.webAndPlatformClientIdsIdentical() =
      WebAndPlatformClientIdsIdentical;
}

class MissingConfigurationValue extends DropConfigurationError {
  final String key;

  const MissingConfigurationValue(this.key);

  @override
  bool operator ==(Object other) =>
      other is MissingConfigurationValue && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'MissingConfigurationValue($key)';
}

class MalformedConfigurationUrl extends DropConfigurationError {
  final String value;

  const MalformedConfigurationUrl(this.value);

  @override
  bool operator ==(Object other) =>
      other is MalformedConfigurationUrl && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'MalformedConfigurationUrl($value)';
}

class WebAndPlatformClientIdsIdentical extends DropConfigurationError {
  const WebAndPlatformClientIdsIdentical();

  @override
  bool operator ==(Object other) => other is WebAndPlatformClientIdsIdentical;

  @override
  int get hashCode => (WebAndPlatformClientIdsIdentical).hashCode;
}

class DropConfiguration {
  final Uri supabaseUrl;
  final String supabaseAnonKey;
  final DropEnvironment environment;

  /// Google 로그인 시 `serverClientId`로 넘길 값. **웹** 클라이언트 ID여야 한다 —
  /// Supabase Google provider가 audience로 신뢰하는 것이 웹 클라이언트 하나뿐이다.
  final String googleWebClientId;

  /// 이 앱 자신의 클라이언트 ID.
  final String googleIosClientId;

  DropConfiguration._({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.environment,
    required this.googleWebClientId,
    required this.googleIosClientId,
  });

  factory DropConfiguration.fromMap(Map<String, Object?> values) {
    final urlString = _require(values, 'SUPABASE_URL');

    // 스킴이 없으면 상대 경로로 받아들여 조용히 통과한다.
    // 빌드 설정이 `//`를 주석으로 먹는 탓에 스킴이 잘린 값이 들어오는 사고가 잦아,
    // 여기서 확실히 끊는다.
    final url = Uri.tryParse(urlString);
    if (url == null || !url.hasScheme || url.host.isEmpty) {
      throw DropConfigurationError.malformedUrl(urlString);
    }

    final environment = switch (values['DROP_ENVIRONMENT']) {
      final String raw => DropEnvironment.fromRaw(raw),
      _ => null,
    };

    final webClientId = _require(values, 'GOOGLE_WEB_CLIENT_ID');
    final iosClientId = _require(values, 'GOOGLE_IOS_CLIENT_ID');

    // 같은 값이면 웹 자리에 플랫폼 것을 넣은 것이다. 그대로 두면 id_token의
    // audience가 플랫폼 클라이언트가 되어 Supabase가 Unacceptable audience로 거부한다.
    if (webClientId == iosClientId) {
      throw const DropConfigurationError.webAndPlatformClientIdsIdentical();
    }

    return DropConfiguration._(
      supabaseUrl: url,
      supabaseAnonKey: _require(values, 'SUPABASE_ANON_KEY'),
      environment: environment ?? DropEnvironment.localdev,
      googleWebClientId: webClientId,
      googleIosClientId: iosClientId,
    );
  }

  static String _require(Map<String, Object?> values, String key) {
    final raw = values[key];
    if (raw is! String) throw DropConfigurationError.missingValue(key);
    final value = raw.trim();
    if (value.isEmpty) throw DropConfigurationError.missingValue(key);
    return value;
  }
}
