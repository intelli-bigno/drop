/// 글자의 **역할** 이름 (BRU-193).
///
/// 크기의 정본은 `design-system/drop/tokens.json`이고 `DropTokenTextSize`(생성물)가
/// 그 값을 나른다. 이 파일이 하는 일은 값에 뜻을 붙이는 것이다 — `drop_theme.dart`가
/// 색에 대해 하는 일과 같은 계층이다.
///
/// 왜 필요한가: 이 계층이 없으면 위젯이 `theme.textTheme.bodySmall`(머티리얼의 스케일,
/// 우리 토큰과 무관)이나 `TextStyle(fontSize: 11)`(그냥 숫자)로 되돌아간다. 실제로
/// `selection_action_bar.dart`가 그랬다.
///
/// **색은 여기 없다.** 같은 `body`가 카드 위에서는 textPrimary, 메타 줄에서는
/// textSecondary다 — 역할이 색까지 쥐면 두 자리를 한 이름으로 못 쓴다. 색은
/// 쓰는 쪽에서 `DropColors.of(context)`로 얹는다.
library;

import 'package:flutter/material.dart';

import 'drop_tokens.g.dart';

abstract final class DropText {
  /// 로그인 화면의 'DROP' 워드마크 **전용**. 읽는 글이 아니라 상표다 —
  /// 본문이 이 크기로 올라오면 안 된다.
  ///
  /// 이 역할이 생기기 전 auth_screen이 `fontSize: 44`를 직접 적고 있었다.
  /// 눈에 보이는 것을 줄이는 대신 스케일이 현실을 기록하게 했다 (tokens.json 3xl).
  static const TextStyle wordmark = TextStyle(
    fontSize: DropTokenTextSize.x3xl,
    fontWeight: FontWeight.w700,
    height: 1.1,
  );

  /// 화면 제목. 앱바가 아니라 화면 본문 맨 위에 서는 큰 제목.
  static const TextStyle screenTitle = TextStyle(
    fontSize: DropTokenTextSize.x2xl,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  /// 섹션 제목. 한 화면 안에서 묶음을 가르는 이름.
  static const TextStyle sectionTitle = TextStyle(
    fontSize: DropTokenTextSize.xl,
    fontWeight: FontWeight.w600,
    height: 1.25,
  );

  /// 카드·행의 제목 줄. 노트 한 줄의 요약이 여기 앉는다.
  static const TextStyle cardTitle = TextStyle(
    fontSize: DropTokenTextSize.lg,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  /// 본문. 읽으라고 있는 글자의 기본값.
  static const TextStyle body = TextStyle(
    fontSize: DropTokenTextSize.base,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  /// 메타. 시각·태그·개수처럼 본문에 딸린 것.
  static const TextStyle meta = TextStyle(
    fontSize: DropTokenTextSize.sm,
    fontWeight: FontWeight.w400,
    height: 1.35,
  );

  /// 가장 작은 글자. 아이콘 밑 이름표처럼 **읽는 글이 아닌** 자리 전용 —
  /// 본문을 여기로 줄이지 마라.
  static const TextStyle caption = TextStyle(
    fontSize: DropTokenTextSize.xs,
    fontWeight: FontWeight.w400,
    height: 1.3,
  );

  /// 감사·쇼케이스가 훑을 역할 목록.
  ///
  /// 새 역할을 만들면 여기에도 넣어라 — 이 지도가 검사의 대상이고,
  /// 빠진 역할은 아무도 검사하지 않는다.
  static const Map<String, TextStyle> roles = {
    'wordmark': wordmark,
    'screenTitle': screenTitle,
    'sectionTitle': sectionTitle,
    'cardTitle': cardTitle,
    'body': body,
    'meta': meta,
    'caption': caption,
  };
}
