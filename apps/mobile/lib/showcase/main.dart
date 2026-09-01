/// 디자인 시스템 쇼케이스의 엔트리포인트 (BRU-193).
///
///     make mobile-showcase
///     # 또는: flutter run -d chrome -t lib/showcase/main.dart
///
/// **앱과 별도 엔트리포인트인 이유**: 쇼케이스는 Supabase·구글 로그인·딥링크를
/// 타지 않아야 브라우저에서 그냥 뜬다. `lib/main.dart`에 라우트로 얹으면
/// 부팅 경로가 인증을 지나므로 로그인 없이는 아무것도 못 본다 —
/// 데스크톱 쇼케이스가 인증 앞단에서 갈라지는 것과 같은 이유다.
///
/// 엔트리포인트가 다르면 출시 번들에도 들어가지 않는다. `flutter build ipa`·
/// `appbundle`은 `lib/main.dart`만 따라가므로 이 트리는 통째로 빠진다.
library;

import 'package:flutter/material.dart';

import 'showcase_app.dart';

void main() => runApp(const ShowcaseApp());
