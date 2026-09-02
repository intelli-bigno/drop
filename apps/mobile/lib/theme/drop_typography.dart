/// 글자의 **역할** 이름 (BRU-193 → BRU-207에서 Pretendard·읽기 본문 추가).
///
/// 크기의 정본은 `design-system/drop/tokens.json`이고 `DropTokenTextSize`(생성물)가
/// 그 값을 나른다. 이 파일이 하는 일은 값에 뜻을 붙이는 것이다 — `drop_theme.dart`가
/// 색에 대해 하는 일과 같은 계층이다.
///
/// 왜 필요한가: 이 계층이 없으면 위젯이 `theme.textTheme.bodySmall`(머티리얼의 스케일,
/// 우리 토큰과 무관)이나 `TextStyle(fontSize: 11)`(그냥 숫자)로 되돌아간다.
///
/// **색은 여기 없다.** 같은 `body`가 카드 위에서는 textPrimary, 메타 줄에서는
/// textSecondary다 — 역할이 색까지 쥐면 두 자리를 한 이름으로 못 쓴다. 색은
/// 쓰는 쪽에서 `DropColors.of(context)`로 얹는다.
///
/// **글꼴은 역할마다 박아 둔다.** 버튼·칩처럼 DefaultTextStyle을 타지 않는 자리가
/// 있어서, 테마의 fontFamily만 믿으면 그 자리만 시스템 글꼴로 새어 나간다.
library;

import 'package:flutter/material.dart';

import 'drop_tokens.g.dart';

abstract final class DropText {
  /// 앱 전체의 글꼴. Pretendard 가변 폰트 하나로 굵기 전 구간을 낸다 —
  /// 한글·라틴 혼용 본문에서 자간·높이가 어긋나지 않는 유일한 선택이었다.
  static const String family = 'Pretendard';

  /// 로그인 화면의 'DROP' 워드마크 **전용**. 읽는 글이 아니라 상표다.
  static const TextStyle wordmark = TextStyle(
    fontFamily: family,
    fontSize: DropTokenTextSize.x3xl,
    fontWeight: FontWeight.w800,
    height: 1.1,
    letterSpacing: -1.5,
  );

  /// 화면 제목. 앱바가 아니라 화면 본문 맨 위에 서는 큰 제목.
  static const TextStyle screenTitle = TextStyle(
    fontFamily: family,
    fontSize: DropTokenTextSize.x2xl,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.6,
  );

  /// 섹션 제목·앱바 제목·시트 제목. 한 화면 안에서 묶음을 가르는 이름.
  static const TextStyle sectionTitle = TextStyle(
    fontFamily: family,
    fontSize: DropTokenTextSize.xl,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: -0.4,
  );

  /// 카드·행의 제목 줄. 노트 한 줄의 요약이 여기 앉는다.
  /// 굵기는 w500 — 목록의 모든 행이 제목이라 w600이면 화면 전체가 무거워진다.
  static const TextStyle cardTitle = TextStyle(
    fontFamily: family,
    fontSize: DropTokenTextSize.lg,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: -0.2,
  );

  /// 읽는 본문. 뷰어·편집기처럼 **문단을 읽는** 자리 — `body`보다 한 단 크고 성기다.
  static const TextStyle reading = TextStyle(
    fontFamily: family,
    fontSize: DropTokenTextSize.lg,
    fontWeight: FontWeight.w400,
    height: 1.65,
    letterSpacing: -0.1,
  );

  /// 본문. 읽으라고 있는 글자의 기본값 — 댓글·설명·행의 부제.
  static const TextStyle body = TextStyle(
    fontFamily: family,
    fontSize: DropTokenTextSize.base,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  /// 누르는 것의 이름 — 버튼·칩·시트의 행동 항목. 본문 크기에 굵기만 올린다.
  static const TextStyle label = TextStyle(
    fontFamily: family,
    fontSize: DropTokenTextSize.base,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: -0.1,
  );

  /// 메타. 시각·태그·개수처럼 본문에 딸린 것.
  static const TextStyle meta = TextStyle(
    fontFamily: family,
    fontSize: DropTokenTextSize.sm,
    fontWeight: FontWeight.w400,
    height: 1.35,
  );

  /// 가장 작은 글자. 아이콘 밑 이름표처럼 **읽는 글이 아닌** 자리 전용.
  static const TextStyle caption = TextStyle(
    fontFamily: family,
    fontSize: DropTokenTextSize.xs,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  /// 감사·쇼케이스가 훑을 역할 목록.
  static const Map<String, TextStyle> roles = {
    'wordmark': wordmark,
    'screenTitle': screenTitle,
    'sectionTitle': sectionTitle,
    'cardTitle': cardTitle,
    'reading': reading,
    'body': body,
    'label': label,
    'meta': meta,
    'caption': caption,
  };
}
