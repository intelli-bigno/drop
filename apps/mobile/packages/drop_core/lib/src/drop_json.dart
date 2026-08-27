/// 프로젝트 전체가 쓰는 JSON 시각 규약. DropCore `DropJSON.swift` 대응.
///
/// 두 가지를 여기서 한 번만 정한다:
/// - 키는 전부 snake_case (모델의 fromJson/insert payload가 직접 지킨다)
/// - Postgres `timestamptz` 파싱. 분수초가 붙은 값과 안 붙은 값이 **둘 다** 온다.
library;

/// Postgres timestamptz 문자열을 UTC `DateTime`으로 읽는다.
/// 분수초(`.123456`)가 있어도 없어도 읽혀야 한다.
DateTime parsePostgresTimestamp(String raw) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) {
    throw FormatException('시각 형식을 알 수 없습니다: $raw');
  }
  return parsed.toUtc();
}

DateTime? parseOptionalPostgresTimestamp(Object? raw) {
  if (raw == null) return null;
  return parsePostgresTimestamp(raw as String);
}

/// 서버로 보낼 시각 표기. ISO 8601 UTC.
String formatPostgresTimestamp(DateTime date) => date.toUtc().toIso8601String();
