/// 앱 전역 디자인 결정 — iOS `DropUI/DropTheme.swift` 대응.
///
/// 색의 **값**은 여기 없다 — 값의 정본은 `design-system/drop/tokens.json`이고
/// `drop_tokens.g.dart`(생성물)가 그것을 나른다. 이 파일이 하는 일은 그 값에
/// **뜻**을 붙이는 것이다: "화면 바탕", "바탕 위에 뜨는 종이". 화면은
/// `bgTertiary`가 아니라 `surfaceField`를 읽는다 — 그래야 토큰 값이 바뀌어도
/// 화면 코드가 흔들리지 않는다.
library;

import 'package:flutter/material.dart';

import 'drop_tokens.g.dart';
import 'drop_typography.dart';

export 'drop_tokens.g.dart';
export 'drop_typography.dart';

/// 간격. iOS `DropTheme.Spacing`과 같은 이름·값 — 정본은 토큰의 4px 스케일이다.
abstract final class DropSpacing {
  static const double tight = DropTokenSpace.x1; // 4
  static const double base = DropTokenSpace.x2; // 8
  static const double comfortable = DropTokenSpace.x4; // 16
  static const double loose = DropTokenSpace.x5; // 24
}

/// 모서리. iOS `DropTheme.Radius` 대응.
abstract final class DropRadius {
  static const double card = DropTokenRadius.lg; // 12
  /// 목록 한 줄 행. 카드보다 조금 작게 — 행이 겹겹이 쌓여도 답답하지 않게 (iOS와 동일).
  static const double row = 10;
  static const double sheet = 20;

  /// 칩·배지처럼 글자를 감싸는 알약. 카드보다 작아야 "누르는 작은 것"으로 읽힌다.
  static const double chip = DropTokenRadius.sm; // 6

  /// 썸네일. 첨부 미리보기가 카드 안에 들어앉는 자리 (BRU-193 이전엔
  /// attachment_thumbnail이 8을 직접 적고 있었다).
  static const double thumbnail = DropTokenRadius.md; // 8
}

/// 아이콘 크기. 토큰이 아니라 **컴포넌트 결정**이라 여기 산다 — `DropRadius.row`와 같은 계층.
///
/// 이름을 붙이는 이유는 값을 아끼려는 게 아니라 **자리를 구분하려는** 것이다.
/// 흩어진 13·14·20·22·28·40을 그대로 두면 다음 위젯이 21을 적어도 아무도 모른다.
abstract final class DropIconSize {
  /// 메타 줄(시각·태그 옆)의 작은 표식.
  static const double meta = 13;

  /// 제목 줄에 끼어드는 표식 — 핀·미아 답글 화살표.
  static const double inline = 14;

  /// 눌러서 상태를 바꾸는 것 — 체크박스·선택 동그라미.
  static const double control = 20;

  /// 액션 바의 동작 아이콘.
  static const double action = 22;

  /// 썸네일을 못 그렸을 때의 자리표시.
  static const double placeholder = 28;

  /// 빈 상태의 큰 아이콘.
  static const double empty = 40;
}

/// 지금 모드(라이트·다크)의 토큰 색 한 벌.
///
/// Swift의 적응형 Color(모드를 스스로 갈아타는 색)가 Flutter엔 없으므로,
/// 화면은 `DropColors.of(context)`로 현재 테마의 한 벌을 받아 쓴다.
abstract final class DropColors {
  static DropTokenColors of(BuildContext context) =>
      switch (Theme.of(context).brightness) {
        Brightness.dark => DropTokenColors.dark,
        Brightness.light => DropTokenColors.light,
      };
}

/// 표면(종이) 역할 이름. iOS `DropTheme.Surface` 대응 —
/// 콘텐츠가 앉는 면은 전부 불투명한 웜 페이퍼다.
extension DropSurfaces on DropTokenColors {
  /// 화면 바탕. 종이 결을 살리려 순백이 아니라 살짝 따뜻한 회백이다.
  Color get surfacePage => bgPrimary;

  /// 바탕 위에 뜨는 종이 — 노트 행·카드.
  Color get surfaceCard => bgCard;

  /// 선택된 행. 액센트를 옅게 깔아 "지금 고른 것"을 표시한다.
  Color get surfaceSelected => accentSubtle;

  /// 입력창·칩처럼 눌러 넣는 3차 표면.
  Color get surfaceField => bgTertiary;
}

/// 토큰 → Flutter `ThemeData`. 라이트가 본체, 다크는 밤용 (tokens.json 규칙).
abstract final class DropTheme {
  static ThemeData get light => _theme(DropTokenColors.light, Brightness.light);
  static ThemeData get dark => _theme(DropTokenColors.dark, Brightness.dark);

  static ThemeData _theme(DropTokenColors colors, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: colors.accent,
      // 두 모드 모두 액센트가 밝은 주황 계열이라 흰 글자는 대비가 모자란다 —
      // 토큰이 정한 어두운 글자를 쓴다 (tokens.json text.on-accent).
      onPrimary: colors.textOnAccent,
      secondary: colors.cta,
      onSecondary: colors.textOnAccent,
      error: colors.danger,
      onError: colors.bgCard,
      surface: colors.surfaceCard,
      onSurface: colors.textPrimary,
      onSurfaceVariant: colors.textSecondary,
      outline: colors.borderColor,
      surfaceContainerHighest: colors.surfaceField,
    );

    final base = ThemeData(colorScheme: scheme, brightness: brightness);
    return base.copyWith(
      scaffoldBackgroundColor: colors.surfacePage,
      // 내비게이션 바는 기능 레이어 — 콘텐츠(종이)보다 살짝 가라앉은 2차 표면.
      appBarTheme: AppBarTheme(
        backgroundColor: colors.bgSecondary,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        titleTextStyle: DropText.sectionTitle.copyWith(color: colors.textPrimary),
      ),
      cardColor: colors.surfaceCard,
      dividerColor: colors.borderColor,
      dividerTheme: DividerThemeData(color: colors.borderColor),
      listTileTheme: ListTileThemeData(
        textColor: colors.textPrimary,
        iconColor: colors.textSecondary,
      ),
      // 머티리얼의 스케일을 우리 역할로 갈아 끼운다. 이걸 안 하면 위젯이
      // `bodyMedium`을 부르는 순간 머티리얼 기본 크기(14/12가 아니라 그쪽 스케일)로
      // 새는데, 그 새는 자리가 눈에 안 보여 조용히 갈라진다.
      textTheme: base.textTheme
          .copyWith(
            headlineSmall: DropText.screenTitle,
            titleLarge: DropText.sectionTitle,
            titleMedium: DropText.cardTitle,
            bodyLarge: DropText.body,
            bodyMedium: DropText.body,
            bodySmall: DropText.meta,
            labelSmall: DropText.caption,
          )
          .apply(
            bodyColor: colors.textPrimary,
            displayColor: colors.textPrimary,
          ),
      progressIndicatorTheme:
          ProgressIndicatorThemeData(color: colors.accent),
    );
  }
}
