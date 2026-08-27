/// 빌드 구성값이 앱으로 들어오는 유일한 입구.
///
/// 값은 `--dart-define-from-file=.config/{local,remote}.json`으로 들어온다
/// (`make mobile-config`가 `.env.local`에서 생성 — scripts/mobile-config.sh).
/// 검증은 drop_core `DropConfiguration.fromMap`이 한다 — 여기서는 읽기만.
library;

/// `--dart-define=DROP_PREVIEW=true`로 켜는 자격증명 없는 프리뷰 모드.
///
/// iOS의 `-dropPreview` 실행 인자 대응 — 인증을 건너뛰고 인메모리 표본을 쓴다.
/// 화면 확인·UI 이슈(BRU-156~)의 실측 경로: `flutter run --dart-define=DROP_PREVIEW=true`
/// 는 `.config/*.json` 없이 뜬다.
const bool isPreviewBuild = bool.fromEnvironment('DROP_PREVIEW');

/// `String.fromEnvironment`는 const 컨텍스트에서만 값을 받으므로 여기 한 번에
/// 모아 둔다. 빈 문자열(=define 누락)은 `DropConfiguration`이 missingValue로 끊는다.
const Map<String, Object?> dartDefineValues = {
  'SUPABASE_URL': String.fromEnvironment('SUPABASE_URL'),
  'SUPABASE_ANON_KEY': String.fromEnvironment('SUPABASE_ANON_KEY'),
  'GOOGLE_IOS_CLIENT_ID': String.fromEnvironment('GOOGLE_IOS_CLIENT_ID'),
  'GOOGLE_WEB_CLIENT_ID': String.fromEnvironment('GOOGLE_WEB_CLIENT_ID'),
  'DROP_ENVIRONMENT': String.fromEnvironment('DROP_ENVIRONMENT'),
};
