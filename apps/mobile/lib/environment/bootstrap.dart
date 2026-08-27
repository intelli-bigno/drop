/// 실행 모드를 정하고 컨테이너를 조립한다. 잘못된 구성이면 여기서 즉시 멈춘다 —
/// 그대로 이어가면 "로그인이 안 된다" 같은 엉뚱한 증상으로 나타나 추적이 길어진다
/// (iOS `DropApp.init`과 같은 규율).
library;

import 'package:drop_core/drop_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import 'drop_environment_container.dart';

Future<DropEnvironmentContainer> bootstrapContainer() async {
  // 자격증명 없는 화면 검증 경로: flutter run --dart-define=DROP_PREVIEW=true
  if (isPreviewBuild) return DropEnvironmentContainer.preview();

  final DropConfiguration configuration;
  try {
    configuration = DropConfiguration.fromMap(dartDefineValues);
  } on DropConfigurationError catch (error) {
    throw StateError('''
빌드 구성을 읽지 못했습니다: $error

  make mobile-config   # .env.local → apps/mobile/.config/{local,remote}.json
  flutter run --dart-define-from-file=.config/local.json

자격증명 없이 화면만 보려면:
  flutter run --dart-define=DROP_PREVIEW=true

자세한 내용은 apps/mobile/README.md.''');
  }

  // 저장된 세션 복원까지 supabase_flutter가 여기서 한다 —
  // 이 await 뒤에는 auth.currentSession이 채워져 AuthStore.restore()가 읽는다.
  await Supabase.initialize(
    url: configuration.supabaseUrl.toString(),
    // 이 프로젝트는 아직 legacy anon key를 쓴다 (publishableKey 전환 전) —
    // 구성 키 이름(SUPABASE_ANON_KEY)과 iOS 쪽 배선이 같은 값을 본다.
    // ignore: deprecated_member_use
    anonKey: configuration.supabaseAnonKey,
  );

  return DropEnvironmentContainer.live(
    configuration: configuration,
    auth: Supabase.instance.client.auth,
  );
}
