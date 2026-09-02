/// 앱 전역 디자인 결정 — iOS `DropUI/DropTheme.swift` 대응.
///
/// 색의 **값**은 여기 없다 — 값의 정본은 `design-system/drop/tokens.json`이고
/// `drop_tokens.g.dart`(생성물)가 그것을 나른다. 이 파일이 하는 일은 그 값에
/// **뜻**을 붙이는 것이다: "화면 바탕", "바탕 위에 뜨는 종이". 화면은
/// `bgTertiary`가 아니라 `surfaceField`를 읽는다 — 그래야 토큰 값이 바뀌어도
/// 화면 코드가 흔들리지 않는다.
///
/// BRU-207: 평면 디자인으로 정리했다. 카드·테두리·그림자·리플을 걷어내고
/// 위계는 **글자 굵기·색·여백**만으로 낸다. 떠 있는 것(시트·메뉴·토스트)은
/// 오버레이 표면 하나(`surfaceOverlay`)로 통일한다.
library;

import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
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

/// 화면 배치 결정. 모든 화면이 **같은 거터 하나**를 쓴다 — 화면마다 16·12·24가
/// 섞이면 스크롤할 때 왼쪽 정렬선이 흔들린다 (BRU-207 착수 시 실측 지적).
abstract final class DropLayout {
  /// 좌우 거터. 제목·행·본문·시트 안쪽까지 전부 이 값에 맞춘다.
  static const double gutter = 20;

  /// 답글 한 단의 들여쓰기. 거터와 같은 값이라 계층이 정렬선 위에 앉는다.
  static const double indent = 20;

  /// 목록 행의 위아래 안쪽 여백.
  static const double rowPadding = DropTokenSpace.x3; // 12

  /// 섹션 사이 — 묶음이 바뀌었다는 것을 여백만으로 알린다.
  static const double sectionGap = DropTokenSpace.x5; // 24

  /// 주요 버튼(로그인·저장) 높이.
  static const double controlHeight = 52;

  /// 칩·작은 버튼 높이.
  static const double chipHeight = 36;
}

/// 모서리. iOS `DropTheme.Radius` 대응.
abstract final class DropRadius {
  static const double card = DropTokenRadius.lg; // 12
  /// 목록 한 줄 행. 카드보다 조금 작게 — 행이 겹겹이 쌓여도 답답하지 않게 (iOS와 동일).
  static const double row = 10;

  /// 바닥 시트 윗모서리. 크게 — 화면 위에 **얹힌 다른 층**으로 읽혀야 한다.
  static const double sheet = 24;

  /// 입력창·버튼처럼 눌러 넣는 면.
  static const double control = 14;

  /// 메뉴·토스트처럼 떠 있는 작은 층.
  static const double overlay = DropTokenRadius.xl; // 16

  /// 칩·배지처럼 글자를 감싸는 알약. 카드보다 작아야 "누르는 작은 것"으로 읽힌다.
  static const double chip = DropTokenRadius.sm; // 6

  /// 썸네일. 첨부 미리보기가 카드 안에 들어앉는 자리.
  static const double thumbnail = DropTokenRadius.md; // 8
}

/// 아이콘 크기. 토큰이 아니라 **컴포넌트 결정**이라 여기 산다 — `DropRadius.row`와 같은 계층.
abstract final class DropIconSize {
  /// 메타 줄(시각·태그 옆)의 작은 표식.
  static const double meta = 13;

  /// 제목 줄에 끼어드는 표식 — 핀·미아 답글 화살표.
  static const double inline = 14;

  /// 눌러서 상태를 바꾸는 것 — 체크박스·선택 동그라미.
  static const double control = 20;

  /// 액션 바·시트 행의 동작 아이콘.
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

  /// 화면 **위에 얹히는** 층 — 시트·메뉴·토스트. 바탕보다 한 단 밝다.
  Color get surfaceOverlay => bgElevated;

  /// 뒤집힌 면 — 켜진 칩·토스트처럼 글자색을 바탕으로 쓰는 자리.
  /// 액센트를 하나 더 쓰지 않고도 "지금 켜진 것"이 가장 강하게 보인다.
  Color get surfaceInverse => textPrimary;

  /// 뒤집힌 면 위의 글자.
  Color get onInverse => bgPrimary;

  /// 마우스가 올라왔을 때 깔리는 색. 글자색을 옅게 — 어느 모드든 바탕과 반대 방향이라
  /// 토큰의 bgHover(바탕과 한 단 차이)보다 확실히 보인다.
  Color get surfaceHover => textPrimary.withValues(alpha: 0.08);

  /// 눌렀을 때 잠깐 깔리는 색. 리플 대신 쓴다 — 호버보다 한 단 진하다.
  Color get surfacePressed => textPrimary.withValues(alpha: 0.14);
}

/// 토큰 → Flutter `ThemeData`. 라이트가 본체, 다크는 밤용 (tokens.json 규칙).
abstract final class DropTheme {
  /// **한 번만 만든다.** getter로 두면 `MaterialApp`이 다시 그릴 때마다 ThemeData
  /// 두 벌을 새로 짓는다 — 하위 테마 15개와 텍스트 스타일 14개를 매번 조립하는
  /// 값비싼 일이고, 인스턴스가 매번 달라져 테마가 안 바뀌었는데도 바뀐 것처럼
  /// 보인다 (BRU-207: 테마 전환 시 메인 스레드 442ms 정지 실측).
  static final ThemeData light = _theme(
    DropTokenColors.light,
    Brightness.light,
  );
  static final ThemeData dark = _theme(DropTokenColors.dark, Brightness.dark);

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
      surface: colors.surfacePage,
      onSurface: colors.textPrimary,
      onSurfaceVariant: colors.textSecondary,
      outline: colors.borderColor,
      outlineVariant: colors.borderSubtle,
      surfaceContainerHighest: colors.surfaceField,
      surfaceContainerHigh: colors.surfaceOverlay,
      // 머티리얼이 표면에 섞는 "틴트"를 끈다 — 우리 표면은 전부 불투명 종이다.
      surfaceTint: colors.surfacePage,
    );

    final base = ThemeData(
      colorScheme: scheme,
      brightness: brightness,
      fontFamily: DropText.family,
      // 리플(잉크 번짐)은 머티리얼의 재질이다. 우리는 눌린 면만 살짝 어둡게 한다.
      splashFactory: NoSplash.splashFactory,
    );

    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(DropRadius.control),
    );

    return base.copyWith(
      // 화면 전환은 모든 플랫폼에서 오른쪽에서 밀려 들어온다(iOS식). 안드로이드·웹의
      // 확대 전환은 "어디서 왔는지"를 말하지 않고, 뒤로 가는 스와이프도 안 된다.
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          for (final platform in TargetPlatform.values)
            platform: const CupertinoPageTransitionsBuilder(),
        },
      ),
      scaffoldBackgroundColor: colors.surfacePage,
      canvasColor: colors.surfacePage,
      highlightColor: colors.surfacePressed,
      hoverColor: colors.surfaceHover,
      splashColor: colors.surfacePressed,
      // 앱바는 화면과 같은 종이다 — 띠를 두르면 화면이 위아래로 갈린다.
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surfacePage,
        surfaceTintColor: colors.surfacePage,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: DropLayout.gutter,
        // 기본 56은 제목과 동작 아이콘이 서로 어깨를 맞대 답답하다 (BRU-207 피드백).
        toolbarHeight: 64,
        titleTextStyle: DropText.sectionTitle.copyWith(
          color: colors.textPrimary,
        ),
        iconTheme: IconThemeData(color: colors.textPrimary),
        actionsIconTheme: IconThemeData(color: colors.textPrimary),
      ),
      cardColor: colors.surfaceCard,
      dividerColor: colors.borderSubtle,
      dividerTheme: DividerThemeData(
        color: colors.borderSubtle,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        textColor: colors.textPrimary,
        iconColor: colors.textSecondary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DropLayout.gutter,
        ),
      ),
      iconTheme: IconThemeData(color: colors.textSecondary),
      // 머티리얼의 스케일을 우리 역할로 갈아 끼운다. 이걸 안 하면 위젯이
      // `bodyMedium`을 부르는 순간 머티리얼 기본 크기로 새는데, 그 새는 자리가
      // 눈에 안 보여 조용히 갈라진다.
      textTheme: base.textTheme
          .copyWith(
            headlineMedium: DropText.screenTitle,
            headlineSmall: DropText.screenTitle,
            titleLarge: DropText.sectionTitle,
            titleMedium: DropText.cardTitle,
            titleSmall: DropText.label,
            bodyLarge: DropText.reading,
            bodyMedium: DropText.body,
            bodySmall: DropText.meta,
            labelLarge: DropText.label,
            labelMedium: DropText.meta,
            labelSmall: DropText.caption,
          )
          .apply(
            bodyColor: colors.textPrimary,
            displayColor: colors.textPrimary,
          ),
      // 주요 버튼: 평면·큰 모서리·굵은 글자. 비활성은 눌러 넣은 면 색으로 가라앉는다.
      // 색은 브랜드 액센트(앰버) 하나 — cta 토큰(주홍)은 앱의 나머지 색과 따로 놀아
      // "다른 앱 버튼"으로 읽혔다 (BRU-207 피드백).
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.accent,
          foregroundColor: colors.textOnAccent,
          disabledBackgroundColor: colors.surfaceField,
          disabledForegroundColor: colors.textMuted,
          elevation: 0,
          minimumSize: const Size(72, 48),
          padding: const EdgeInsets.symmetric(horizontal: DropLayout.gutter),
          shape: controlShape,
          textStyle: DropText.label,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.textPrimary,
          disabledForegroundColor: colors.textMuted,
          minimumSize: const Size(48, 40),
          padding: const EdgeInsets.symmetric(horizontal: DropTokenSpace.x3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DropTokenRadius.md),
          ),
          textStyle: DropText.label,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          side: BorderSide(color: colors.borderColor),
          minimumSize: const Size(72, 48),
          padding: const EdgeInsets.symmetric(horizontal: DropLayout.gutter),
          shape: controlShape,
          textStyle: DropText.label,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: colors.textPrimary,
          disabledForegroundColor: colors.textMuted,
          hoverColor: colors.surfaceHover,
          highlightColor: colors.surfacePressed,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.accent,
        foregroundColor: colors.textOnAccent,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: const CircleBorder(),
        iconSize: 28,
      ),
      // 바닥 시트 = 오버레이 층. 손잡이가 "끌어내릴 수 있다"를 말한다.
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surfaceOverlay,
        surfaceTintColor: colors.surfaceOverlay,
        modalBackgroundColor: colors.surfaceOverlay,
        // 스크림은 두 모드 다 **어둡게** — 라이트의 글자색(진회색)은 되지만
        // 다크의 글자색(연회색)을 깔면 화면이 뿌옇게 바랜다. 다크 바탕 토큰을 빌린다.
        modalBarrierColor: DropTokenColors.dark.bgPrimary.withValues(
          alpha: 0.55,
        ),
        showDragHandle: true,
        dragHandleColor: colors.textMuted,
        dragHandleSize: const Size(36, 4),
        elevation: 0,
        modalElevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(DropRadius.sheet),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surfaceOverlay,
        surfaceTintColor: colors.surfaceOverlay,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DropRadius.overlay),
          side: BorderSide(color: colors.borderSubtle),
        ),
        textStyle: DropText.body.copyWith(color: colors.textPrimary),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceOverlay,
        surfaceTintColor: colors.surfaceOverlay,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DropRadius.sheet),
        ),
        titleTextStyle: DropText.sectionTitle.copyWith(
          color: colors.textPrimary,
        ),
        contentTextStyle: DropText.body.copyWith(color: colors.textSecondary),
      ),
      // 토스트는 뒤집힌 면 — 화면 위에 잠깐 떠서 한 줄만 말하고 사라진다.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.surfaceInverse,
        contentTextStyle: DropText.body.copyWith(color: colors.onInverse),
        actionTextColor: colors.accent,
        elevation: 0,
        insetPadding: const EdgeInsets.fromLTRB(
          DropLayout.gutter,
          0,
          DropLayout.gutter,
          DropLayout.gutter,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DropRadius.control),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
        hintStyle: DropText.reading.copyWith(color: colors.textMuted),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.accent,
        selectionColor: colors.accentSubtle,
        selectionHandleColor: colors.accent,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: colors.accent),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DropRadius.chip),
        ),
      ),
    );
  }
}
