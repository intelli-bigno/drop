#!/usr/bin/env node
/**
 * design-system/drop/tokens.json → 세 플랫폼의 토큰 파일.
 *
 *   데스크톱  apps/desktop/src/renderer/styles/tokens.css   (CSS 변수)
 *   iOS       apps/ios/Packages/DropUI/Sources/DropUI/DropTokens.swift
 *   Android   apps/android/app/src/main/kotlin/com/intellieffect/drop/android/DropTokens.kt
 *   Flutter   apps/mobile/lib/theme/drop_tokens.g.dart
 *   위젯      apps/mobile/android/app/src/main/res/values{,-night}/drop_tokens.xml
 *
 * 위젯 산출물이 따로 있는 이유: 홈 화면 위젯은 RemoteViews라 색을 **리소스**로만 받는다
 * (BRU-189). Compose용 Kotlin 토큰(위 Android 항목)은 동결된 네이티브 앱 전용이라 못 쓴다.
 *
 * 왜 Style Dictionary가 아니라 이 스크립트인가:
 * 산출 형식 셋이 전부 이 레포 전용이다 — CSS는 기존 변수명을 글자 그대로 지켜야 하고,
 * Swift는 DropUI의 기존 구조에 얹히고, Kotlin은 Compose ColorScheme이다. 라이브러리를 써도
 * 포맷 셋을 직접 짜게 되므로 얻는 것이 없고, 루트 package.json에 의존만 하나 늘어난다.
 *
 * 생성물은 커밋한다. iOS·Android 빌드가 Node에 의존하면 `make ios-test`·`make android-test`가
 * 툴체인 하나로 도는 전제가 깨진다. CI는 "재생성 후 diff 없음"만 확인한다.
 *
 * 사용: node scripts/build-tokens.mjs [--check]
 *   --check  파일을 쓰지 않고, 생성물이 최신인지만 확인한다 (CI용)
 */

import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const SOURCE = join(ROOT, 'design-system/drop/tokens.json');
const CHECK_ONLY = process.argv.includes('--check');

const BANNER_LINES = [
  '이 파일은 생성물이다 — 직접 고치지 마라.',
  '정본: design-system/drop/tokens.json',
  '재생성: make tokens',
];

// ── 읽기 ────────────────────────────────────────────────────────────────────

/** `$`로 시작하는 키는 주석·메타다. 값 순회에서 제외한다. */
const isMeta = (key) => key.startsWith('$');

const tokens = JSON.parse(readFileSync(SOURCE, 'utf8'));
const MODES = tokens.modes;

/**
 * 색 트리를 평평한 목록으로 편다.
 * `{ bg: { primary: {...} } }` → `[{ path: ['bg','primary'], value: {...} }]`
 * `$self`는 부모 이름 그대로를 뜻한다 (accent.$self → accent).
 */
function flattenColors(node, path = []) {
  const out = [];
  for (const [key, value] of Object.entries(node)) {
    if (isMeta(key) && key !== '$self') continue;
    if (key === '$self') {
      out.push({ path, value });
      continue;
    }
    const next = [...path, key];
    // 리프인지(모드 키를 들고 있는지) 판단한다.
    const isLeaf = 'shared' in value || MODES.some((mode) => mode in value);
    if (isLeaf) out.push({ path: next, value });
    else out.push(...flattenColors(value, next));
  }
  return out;
}

const colors = flattenColors(tokens.color);

/** `{color.accent}` 참조를 실제 값으로 바꾼다. */
function resolve(raw, mode) {
  const reference = /^\{([^}]+)\}$/.exec(String(raw));
  if (!reference) return raw;

  const wanted = reference[1].replace(/^color\./, '').split('.');
  const target = colors.find((color) => color.path.join('.') === wanted.join('.'));
  if (!target) throw new Error(`알 수 없는 토큰 참조: ${raw}`);
  return valueFor(target.value, mode);
}

/** 풀지 않은 원값. 참조(`{color.accent}`)인지 판단하는 데 쓴다. */
function rawFor(value, mode) {
  const raw = 'shared' in value ? value.shared : value[mode];
  if (raw === undefined) {
    throw new Error(`모드 ${mode}에 값이 없다: ${JSON.stringify(value)}`);
  }
  return raw;
}

function valueFor(value, mode) {
  return resolve(rawFor(value, mode), mode);
}

/**
 * CSS에서는 참조를 **풀지 않고** `var(--accent)`로 남긴다.
 *
 * 별칭을 유지해야 모드가 늘 때 따라온다 — `--border-focus`를 리터럴로 박으면
 * 라이트 블록에서 그 색만 따로 관리하게 되고, 언젠가 accent와 어긋난다.
 * 네이티브(Swift·Kotlin)에는 이런 간접 참조가 없으므로 거기서는 푼다.
 */
function cssValueFor(value, mode) {
  const raw = rawFor(value, mode);
  const reference = /^\{([^}]+)\}$/.exec(String(raw));
  if (!reference) return raw;
  return `var(--${kebab(reference[1].replace(/^color\./, '').split('.'))})`;
}

// ── 색 표현 변환 ─────────────────────────────────────────────────────────────

/** `#rrggbb` 또는 `rgba(r, g, b, a)` → { r, g, b, a } (0~1) */
function parseColor(raw) {
  const hex = /^#([0-9a-f]{6})$/i.exec(raw);
  if (hex) {
    const int = parseInt(hex[1], 16);
    return { r: ((int >> 16) & 255) / 255, g: ((int >> 8) & 255) / 255, b: (int & 255) / 255, a: 1 };
  }

  const rgba = /^rgba?\(([^)]+)\)$/i.exec(raw);
  if (rgba) {
    const [r, g, b, a = '1'] = rgba[1].split(',').map((part) => part.trim());
    return { r: Number(r) / 255, g: Number(g) / 255, b: Number(b) / 255, a: Number(a) };
  }

  throw new Error(`색 형식을 모르겠다: ${raw}`);
}

const round = (n) => Number(n.toFixed(3));

/** Compose Color는 0xAARRGGBB. */
function toArgbHex(raw) {
  const { r, g, b, a } = parseColor(raw);
  const byte = (n) => Math.round(n * 255).toString(16).padStart(2, '0').toUpperCase();
  return `0x${byte(a)}${byte(r)}${byte(g)}${byte(b)}`;
}

// ── 이름 변환 ────────────────────────────────────────────────────────────────

const kebab = (path) => path.join('-');

/**
 * `['danger-hover']` → `dangerHover`.
 *
 * 경로 사이뿐 아니라 **한 조각 안의 하이픈까지** 없앤다 — 안 그러면 `danger-hover`가
 * 그대로 식별자로 나가 Swift·Kotlin이 컴파일되지 않는다(실제로 그렇게 깨졌다).
 */
const camel = (path) =>
  path
    .flatMap((part) => part.split('-'))
    .map((part, index) => (index === 0 ? part : part[0].toUpperCase() + part.slice(1)))
    .join('')
    // `2xl` 같은 숫자 시작 이름은 식별자가 못 된다.
    .replace(/^(\d)/, '_$1');

// ── 생성: CSS ───────────────────────────────────────────────────────────────

/** 한 모드의 색·그림자 변수 줄들. 선택자 안에 들어갈 본문이다. */
function cssModeVars(mode, indent) {
  const lines = [];
  for (const color of colors) {
    lines.push(`${indent}--${kebab(color.path)}: ${cssValueFor(color.value, mode)};`);
  }
  for (const [key, value] of Object.entries(tokens.shadow)) {
    if (isMeta(key)) continue;
    lines.push(`${indent}--shadow-${key}: ${cssValueFor(value, mode)};`);
  }
  return lines;
}

function buildCss() {
  const lines = [`/*`, ...BANNER_LINES.map((line) => ` * ${line}`), ` */`, ``];
  const base = MODES[0];

  for (const mode of MODES) {
    if (mode !== base) {
      // 기본이 아닌 모드는 두 경로로 들어온다:
      //   1) 시스템 설정을 따라갈 때 — 단, 사용자가 기본 모드를 명시했으면 그쪽이 이긴다
      //   2) data-theme로 명시했을 때
      // 둘 다 없으면 "시스템은 다크인데 앱만 라이트"가 되거나 토글이 안 먹는다.
      lines.push(`@media (prefers-color-scheme: ${mode}) {`);
      lines.push(`  :root:not([data-theme='${base}']) {`);
      lines.push(...cssModeVars(mode, '    '));
      lines.push(`  }`, `}`, ``);
    }

    const selector = mode === base ? ':root' : `:root[data-theme='${mode}']`;
    lines.push(`${selector} {`);
    lines.push(...cssModeVars(mode, '  '));

    // 모드와 무관한 값은 첫 블록에만 쓴다.
    if (mode === base) {
      lines.push(``);
      for (const [key, value] of Object.entries(tokens.space)) {
        if (isMeta(key)) continue;
        lines.push(`  --space-${key}: ${value}px;`);
      }
      lines.push(``);
      for (const [key, value] of Object.entries(tokens.radius)) {
        if (isMeta(key)) continue;
        lines.push(`  --radius-${key}: ${value}px;`);
      }
      lines.push(``);
      for (const [key, value] of Object.entries(tokens['text-size'])) {
        if (isMeta(key)) continue;
        lines.push(`  --text-${key}: ${value}px;`);
      }
      lines.push(``);
      for (const [key, value] of Object.entries(tokens.font)) {
        if (isMeta(key)) continue;
        lines.push(`  --font-${key}: ${value.css};`);
      }
      lines.push(``);
      for (const [key, value] of Object.entries(tokens.transition)) {
        if (isMeta(key)) continue;
        lines.push(`  --transition-${key}: ${value};`);
      }
    }

    lines.push(`}`, ``);
  }

  return lines.join('\n');
}

// ── 생성: Swift ─────────────────────────────────────────────────────────────

function swiftColor(raw) {
  const { r, g, b, a } = parseColor(raw);
  const base = `Color(red: ${round(r)}, green: ${round(g)}, blue: ${round(b)})`;
  return a === 1 ? base : `${base}.opacity(${round(a)})`;
}

function buildSwift() {
  const lines = [
    ...BANNER_LINES.map((line) => `// ${line}`),
    ``,
    `import SwiftUI`,
    // 적응형 색(UIColor 동적 제공자)을 만들려면 UIKit이 필요하다. DropUI는 iOS 전용이다.
    `import UIKit`,
    ``,
    `/// 생성된 색·치수 토큰. 화면은 이 값만 쓴다 — 리터럴 색을 화면에 적으면`,
    `/// 세 앱의 색이 다시 갈라진다.`,
    `public enum DropTokens {`,
    `    public enum Colors {`,
  ];

  for (const color of colors) {
    const name = camel(color.path);
    if (MODES.length === 1) {
      lines.push(`        public static let ${name} = ${swiftColor(valueFor(color.value, MODES[0]))}`);
    } else {
      // 모드를 인자로 받지 않는다 — 화면이 색을 쓸 때마다 모드를 들고 다니면
      // 한 곳만 빠뜨려도 그 뷰만 반대 테마로 남는다. 시스템 설정을 따라
      // 스스로 바뀌는 색으로 만든다.
      lines.push(
        `        public static let ${name} = DropTokens.adaptive(` +
          `light: ${swiftColor(valueFor(color.value, 'light'))}, ` +
          `dark: ${swiftColor(valueFor(color.value, 'dark'))})`,
      );
    }
  }

  lines.push(`    }`, ``);

  // 라이트·다크 두 벌이 있을 때만 적응형 생성자가 필요하다.
  if (MODES.length > 1) {
    lines.push(
      `    /// 시스템 외양에 따라 스스로 바뀌는 색.`,
      `    ///`,
      `    /// SwiftUI \`Color\`는 두 값을 품지 못해서 UIKit의 동적 색으로 만든다 —`,
      `    /// 이렇게 해야 다크 모드 전환이 뷰 코드 없이 즉시 반영된다.`,
      `    fileprivate static func adaptive(light: Color, dark: Color) -> Color {`,
      `        Color(UIColor { traits in`,
      `            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)`,
      `        })`,
      `    }`,
      ``,
    );
  }

  lines.push(`    public enum Space {`);
  for (const [key, value] of Object.entries(tokens.space)) {
    if (isMeta(key)) continue;
    lines.push(`        public static let x${key}: CGFloat = ${value}`);
  }
  lines.push(`    }`, ``, `    public enum Radius {`);
  for (const [key, value] of Object.entries(tokens.radius)) {
    if (isMeta(key)) continue;
    lines.push(`        public static let ${key}: CGFloat = ${value}`);
  }
  lines.push(`    }`, ``, `    public enum TextSize {`);
  for (const [key, value] of Object.entries(tokens['text-size'])) {
    if (isMeta(key)) continue;
    lines.push(`        public static let ${camel([key])}: CGFloat = ${value}`);
  }
  lines.push(`    }`, `}`, ``);

  return lines.join('\n');
}

// ── 생성: Kotlin ────────────────────────────────────────────────────────────

function buildKotlin() {
  const lines = [
    ...BANNER_LINES.map((line) => `// ${line}`),
    ``,
    `package com.intellieffect.drop.android`,
    ``,
    `import androidx.compose.ui.graphics.Color`,
    `import androidx.compose.ui.unit.dp`,
    `import androidx.compose.ui.unit.sp`,
    ``,
    `/**`,
    ` * 생성된 색·치수 토큰. 화면은 이 값만 쓴다 — 리터럴 색을 Composable에 적으면`,
    ` * 세 앱의 색이 다시 갈라진다.`,
    ` */`,
    `object DropTokens {`,
  ];

  for (const mode of MODES) {
    const objectName = mode[0].toUpperCase() + mode.slice(1);
    lines.push(`    object ${objectName} {`);
    for (const color of colors) {
      lines.push(`        val ${camel(color.path)} = Color(${toArgbHex(valueFor(color.value, mode))})`);
    }
    lines.push(`    }`, ``);
  }

  lines.push(`    object Space {`);
  for (const [key, value] of Object.entries(tokens.space)) {
    if (isMeta(key)) continue;
    lines.push(`        val x${key} = ${value}.dp`);
  }
  lines.push(`    }`, ``, `    object Radius {`);
  for (const [key, value] of Object.entries(tokens.radius)) {
    if (isMeta(key)) continue;
    lines.push(`        val ${key} = ${value}.dp`);
  }
  lines.push(`    }`, ``, `    object TextSize {`);
  for (const [key, value] of Object.entries(tokens['text-size'])) {
    if (isMeta(key)) continue;
    lines.push(`        val ${camel([key])} = ${value}.sp`);
  }
  lines.push(`    }`, `}`, ``);

  return lines.join('\n');
}

// ── 생성: Android 리소스 XML (Flutter 앱의 홈 화면 위젯, BRU-189) ────────────

/** 리소스 이름은 `[a-z0-9_]`만 받는다 — `danger-hover` → `drop_danger_hover`. */
const resourceName = (path) => ['drop', ...path.flatMap((part) => part.split('-'))].join('_');

/** Android 색 리터럴은 `#AARRGGBB`. */
function toAndroidHex(raw) {
  const { r, g, b, a } = parseColor(raw);
  const byte = (n) => Math.round(n * 255).toString(16).padStart(2, '0').toUpperCase();
  return `#${byte(a)}${byte(r)}${byte(g)}${byte(b)}`;
}

/**
 * 한 모드의 색 리소스. 다크는 `values-night/`로 따로 나가고, 시스템이 골라 준다 —
 * 위젯 코드가 모드를 판정하면 다크 전환이 위젯 갱신 때까지 밀린다.
 *
 * 치수(dimen)는 모드와 무관하므로 기본 모드 파일에만 넣는다.
 */
function buildAndroidResources(mode, { withDimensions }) {
  const lines = [
    `<?xml version="1.0" encoding="utf-8"?>`,
    `<!--`,
    ...BANNER_LINES.map((line) => `  ${line}`),
    `-->`,
    `<resources>`,
  ];

  for (const color of colors) {
    lines.push(`    <color name="${resourceName(color.path)}">${toAndroidHex(valueFor(color.value, mode))}</color>`);
  }

  if (withDimensions) {
    lines.push(``);
    for (const [key, value] of Object.entries(tokens.space)) {
      if (isMeta(key)) continue;
      lines.push(`    <dimen name="drop_space_x${key}">${value}dp</dimen>`);
    }
    lines.push(``);
    for (const [key, value] of Object.entries(tokens.radius)) {
      if (isMeta(key)) continue;
      lines.push(`    <dimen name="drop_radius_${key}">${value}dp</dimen>`);
    }
    lines.push(``);
    for (const [key, value] of Object.entries(tokens['text-size'])) {
      if (isMeta(key)) continue;
      // `2xl`은 리소스 이름이 못 되므로 숫자 앞에 `x`를 붙인다.
      lines.push(`    <dimen name="drop_text_${key.replace(/^(\d)/, 'x$1')}">${value}sp</dimen>`);
    }
  }

  lines.push(`</resources>`, ``);
  return lines.join('\n');
}

// ── 생성: Dart ──────────────────────────────────────────────────────────────

/**
 * Dart 식별자. `2xl` 같은 숫자 시작 이름은 camel이 `_2xl`을 만드는데,
 * Dart에서 선행 밑줄은 **라이브러리 프라이빗**이라 밖에서 못 읽는다 — `x`를 앞에 붙인다.
 */
const dartIdent = (path) => camel(path).replace(/^_/, 'x');

function buildDart() {
  const colorField = (color) => dartIdent(color.path);

  const lines = [
    `// generated — do not edit, run \`make tokens\``,
    ...BANNER_LINES.map((line) => `// ${line}`),
    ``,
    `import 'dart:ui';`,
    ``,
    `/// 생성된 색 토큰 — 라이트·다크 한 벌씩. 화면은 이 값(을 나르는 DropTheme)만`,
    `/// 쓴다 — 리터럴 색을 위젯에 적으면 네 앱의 색이 다시 갈라진다.`,
    `///`,
    `/// Swift처럼 스스로 모드를 갈아타는 Color가 Flutter엔 없으므로 두 벌을 다`,
    `/// 내보내고, 모드 판정은 lib/theme/drop_theme.dart(ThemeData)가 한다.`,
    `class DropTokenColors {`,
    `  const DropTokenColors._({`,
    ...colors.map((color) => `    required this.${colorField(color)},`),
    `  });`,
    ``,
    ...colors.map((color) => `  final Color ${colorField(color)};`),
  ];

  for (const mode of MODES) {
    lines.push(``, `  static const DropTokenColors ${mode} = DropTokenColors._(`);
    for (const color of colors) {
      lines.push(
        `    ${colorField(color)}: Color(${toArgbHex(valueFor(color.value, mode))}),`,
      );
    }
    lines.push(`  );`);
  }

  lines.push(`}`, ``, `abstract final class DropTokenSpace {`);
  for (const [key, value] of Object.entries(tokens.space)) {
    if (isMeta(key)) continue;
    lines.push(`  static const double x${key} = ${value};`);
  }
  lines.push(`}`, ``, `abstract final class DropTokenRadius {`);
  for (const [key, value] of Object.entries(tokens.radius)) {
    if (isMeta(key)) continue;
    lines.push(`  static const double ${dartIdent([key])} = ${value};`);
  }
  lines.push(`}`, ``, `abstract final class DropTokenTextSize {`);
  for (const [key, value] of Object.entries(tokens['text-size'])) {
    if (isMeta(key)) continue;
    lines.push(`  static const double ${dartIdent([key])} = ${value};`);
  }
  lines.push(`}`, ``);

  return lines.join('\n');
}

// ── 쓰기 ────────────────────────────────────────────────────────────────────

const OUTPUTS = [
  { path: 'apps/desktop/src/renderer/styles/tokens.css', build: buildCss },
  { path: 'apps/ios/Packages/DropUI/Sources/DropUI/DropTokens.swift', build: buildSwift },
  {
    path: 'apps/android/app/src/main/kotlin/com/intellieffect/drop/android/DropTokens.kt',
    build: buildKotlin,
  },
  { path: 'apps/mobile/lib/theme/drop_tokens.g.dart', build: buildDart },
  {
    path: 'apps/mobile/android/app/src/main/res/values/drop_tokens.xml',
    build: () => buildAndroidResources(MODES[0], { withDimensions: true }),
  },
  {
    path: 'apps/mobile/android/app/src/main/res/values-night/drop_tokens.xml',
    build: () => buildAndroidResources('dark', { withDimensions: false }),
  },
];

let stale = false;

for (const output of OUTPUTS) {
  const target = join(ROOT, output.path);
  const next = output.build();

  if (CHECK_ONLY) {
    let current = null;
    try {
      current = readFileSync(target, 'utf8');
    } catch {
      // 파일이 없으면 최신이 아니다.
    }
    if (current !== next) {
      console.error(`❌ 최신이 아니다: ${output.path}`);
      stale = true;
    }
    continue;
  }

  writeFileSync(target, next);
  console.log(`✅ ${output.path}`);
}

if (CHECK_ONLY) {
  if (stale) {
    console.error('\n`make tokens`를 돌리고 생성물을 함께 커밋해라.');
    process.exit(1);
  }
  console.log('✅ 토큰 생성물이 최신이다');
}
