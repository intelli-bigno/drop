// generated — do not edit, run `make tokens`
// 이 파일은 생성물이다 — 직접 고치지 마라.
// 정본: design-system/drop/tokens.json
// 재생성: make tokens

import 'dart:ui';

/// 생성된 색 토큰 — 라이트·다크 한 벌씩. 화면은 이 값(을 나르는 DropTheme)만
/// 쓴다 — 리터럴 색을 위젯에 적으면 네 앱의 색이 다시 갈라진다.
///
/// Swift처럼 스스로 모드를 갈아타는 Color가 Flutter엔 없으므로 두 벌을 다
/// 내보내고, 모드 판정은 lib/theme/drop_theme.dart(ThemeData)가 한다.
class DropTokenColors {
  const DropTokenColors._({
    required this.bgPrimary,
    required this.bgSecondary,
    required this.bgCard,
    required this.bgElevated,
    required this.bgTertiary,
    required this.bgHover,
    required this.accent,
    required this.accentHover,
    required this.accentSubtle,
    required this.cta,
    required this.ctaHover,
    required this.textOnAccent,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textMuted,
    required this.borderColor,
    required this.borderSubtle,
    required this.borderFocus,
    required this.priorityLow,
    required this.priorityMedium,
    required this.priorityHigh,
    required this.success,
    required this.warning,
    required this.danger,
    required this.dangerHover,
    required this.brandInstagram,
    required this.brandYoutube,
  });

  final Color bgPrimary;
  final Color bgSecondary;
  final Color bgCard;
  final Color bgElevated;
  final Color bgTertiary;
  final Color bgHover;
  final Color accent;
  final Color accentHover;
  final Color accentSubtle;
  final Color cta;
  final Color ctaHover;
  final Color textOnAccent;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textMuted;
  final Color borderColor;
  final Color borderSubtle;
  final Color borderFocus;
  final Color priorityLow;
  final Color priorityMedium;
  final Color priorityHigh;
  final Color success;
  final Color warning;
  final Color danger;
  final Color dangerHover;
  final Color brandInstagram;
  final Color brandYoutube;

  static const DropTokenColors light = DropTokenColors._(
    bgPrimary: Color(0xFFF7F6F3),
    bgSecondary: Color(0xFFF1EFEA),
    bgCard: Color(0xFFFFFFFF),
    bgElevated: Color(0xFFFFFFFF),
    bgTertiary: Color(0xFFEDEAE3),
    bgHover: Color(0xFFEDEAE3),
    accent: Color(0xFFD9730D),
    accentHover: Color(0xFFB45309),
    accentSubtle: Color(0x1FD9730D),
    cta: Color(0xFFD0460D),
    ctaHover: Color(0xFF9A3412),
    textOnAccent: Color(0xFF000000),
    textPrimary: Color(0xFF37352F),
    textSecondary: Color(0xFF6B6862),
    textTertiary: Color(0xFF8D8C89),
    textMuted: Color(0xFFB4B2AC),
    borderColor: Color(0x1F37352F),
    borderSubtle: Color(0x0F37352F),
    borderFocus: Color(0xFFD9730D),
    priorityLow: Color(0xFF6B7280),
    priorityMedium: Color(0xFFF59E0B),
    priorityHigh: Color(0xFFEF4444),
    success: Color(0xFF22C55E),
    warning: Color(0xFFF59E0B),
    danger: Color(0xFFDA2323),
    dangerHover: Color(0xFFB91C1C),
    brandInstagram: Color(0xFFE1306C),
    brandYoutube: Color(0xFFFF0000),
  );

  static const DropTokenColors dark = DropTokenColors._(
    bgPrimary: Color(0xFF191919),
    bgSecondary: Color(0xFF1C1C1C),
    bgCard: Color(0xFF202020),
    bgElevated: Color(0xFF262626),
    bgTertiary: Color(0xFF2A2A2A),
    bgHover: Color(0xFF2E2E2E),
    accent: Color(0xFFE9A23B),
    accentHover: Color(0xFFF2B45A),
    accentSubtle: Color(0x24E9A23B),
    cta: Color(0xFFF97316),
    ctaHover: Color(0xFFFB923C),
    textOnAccent: Color(0xFF000000),
    textPrimary: Color(0xFFD4D4D4),
    textSecondary: Color(0xFFA8A6A1),
    textTertiary: Color(0xFF8C8C8C),
    textMuted: Color(0xFF6B6A66),
    borderColor: Color(0x17FFFFFF),
    borderSubtle: Color(0x0DFFFFFF),
    borderFocus: Color(0xFFE9A23B),
    priorityLow: Color(0xFF6B7280),
    priorityMedium: Color(0xFFF59E0B),
    priorityHigh: Color(0xFFEF4444),
    success: Color(0xFF22C55E),
    warning: Color(0xFFF59E0B),
    danger: Color(0xFFEF4444),
    dangerHover: Color(0xFFF87171),
    brandInstagram: Color(0xFFE1306C),
    brandYoutube: Color(0xFFFF0000),
  );

  /// 이름 → 값. 쇼케이스·감사처럼 토큰 전체를 훑어야 하는 쪽을 위한 것이다.
  Map<String, Color> get all => {
    'bg-primary': bgPrimary,
    'bg-secondary': bgSecondary,
    'bg-card': bgCard,
    'bg-elevated': bgElevated,
    'bg-tertiary': bgTertiary,
    'bg-hover': bgHover,
    'accent': accent,
    'accent-hover': accentHover,
    'accent-subtle': accentSubtle,
    'cta': cta,
    'cta-hover': ctaHover,
    'text-on-accent': textOnAccent,
    'text-primary': textPrimary,
    'text-secondary': textSecondary,
    'text-tertiary': textTertiary,
    'text-muted': textMuted,
    'border-color': borderColor,
    'border-subtle': borderSubtle,
    'border-focus': borderFocus,
    'priority-low': priorityLow,
    'priority-medium': priorityMedium,
    'priority-high': priorityHigh,
    'success': success,
    'warning': warning,
    'danger': danger,
    'danger-hover': dangerHover,
    'brand-instagram': brandInstagram,
    'brand-youtube': brandYoutube,
  };
}

abstract final class DropTokenSpace {
  static const double x1 = 4;
  static const double x2 = 8;
  static const double x3 = 12;
  static const double x4 = 16;
  static const double x5 = 24;
  static const double x6 = 32;
  static const double x7 = 48;
  static const double x8 = 64;

  /// 이름 → 값. 쇼케이스가 스케일을 훑을 때 쓴다.
  static const Map<String, double> all = {
    'space-1': x1,
    'space-2': x2,
    'space-3': x3,
    'space-4': x4,
    'space-5': x5,
    'space-6': x6,
    'space-7': x7,
    'space-8': x8,
  };
}

abstract final class DropTokenRadius {
  static const double sm = 6;
  static const double md = 8;
  static const double lg = 12;
  static const double xl = 16;

  /// 이름 → 값. 쇼케이스가 스케일을 훑을 때 쓴다.
  static const Map<String, double> all = {
    'radius-sm': sm,
    'radius-md': md,
    'radius-lg': lg,
    'radius-xl': xl,
  };
}

abstract final class DropTokenTextSize {
  static const double xs = 11;
  static const double sm = 12;
  static const double base = 14;
  static const double lg = 16;
  static const double xl = 20;
  static const double x2xl = 28;
  static const double x3xl = 44;

  /// 이름 → 값. 쇼케이스가 스케일을 훑을 때 쓴다.
  static const Map<String, double> all = {
    'text-xs': xs,
    'text-sm': sm,
    'text-base': base,
    'text-lg': lg,
    'text-xl': xl,
    'text-2xl': x2xl,
    'text-3xl': x3xl,
  };
}
