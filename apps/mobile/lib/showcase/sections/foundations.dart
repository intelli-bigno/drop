/// Foundations — 토큰 (BRU-193). 데스크톱 `styleguide/sections/Foundations.tsx` 대응.
///
/// **값을 여기 적지 않는다.** 생성물이 내보내는 `all` 지도를 훑어 그린다 —
/// 베껴 적는 순간 tokens.json과 갈라지고 쇼케이스가 거짓말을 시작한다.
/// 그래서 `make tokens`를 돌리면 이 화면이 바로 따라온다.
library;

import 'package:flutter/material.dart';

import '../../theme/drop_theme.dart';
import '../parts.dart';

class FoundationsSection extends StatelessWidget {
  const FoundationsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = DropColors.of(context);

    return ListView(
      padding: const EdgeInsets.all(DropTokenSpace.x5),
      children: [
        const PageHead(
          title: 'Foundations',
          lede: '색·간격·모서리·글자의 정본은 design-system/drop/tokens.json 하나이고, '
              '같은 값이 데스크톱·iOS·Android로도 나간다. 아래는 생성물에서 읽어 온 것이라 '
              'make tokens를 돌리면 여기도 따라 바뀐다.',
        ),
        ShowcaseSection(
          title: '색',
          note: '지금 모드(${Theme.of(context).brightness.name})에 적용된 값이다. '
              '좌측 하단에서 모드를 바꾸면 전부 갈아탄다.',
          child: Wrap(
            spacing: DropTokenSpace.x2,
            runSpacing: DropTokenSpace.x2,
            children: [
              for (final MapEntry(key: name, value: value) in colors.all.entries)
                _Swatch(name: name, color: value),
            ],
          ),
        ),
        ShowcaseSection(
          title: '간격',
          note: '4px 베이스. 화면은 이 눈금 위에만 앉는다.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final MapEntry(key: name, value: value)
                  in DropTokenSpace.all.entries)
                _ScaleBar(name: name, value: value, colors: colors),
            ],
          ),
        ),
        ShowcaseSection(
          title: '모서리',
          child: Wrap(
            spacing: DropTokenSpace.x3,
            runSpacing: DropTokenSpace.x3,
            children: [
              for (final MapEntry(key: name, value: value)
                  in DropTokenRadius.all.entries)
                _RadiusChip(name: name, value: value, colors: colors),
            ],
          ),
        ),
        ShowcaseSection(
          title: '글자 — 역할',
          note: '화면은 숫자가 아니라 이 역할 이름을 쓴다 (DropText). '
              '감사 테스트가 fontSize 숫자를 금지한다.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final MapEntry(key: name, value: style)
                  in DropText.roles.entries)
                _TypeRow(name: name, style: style, colors: colors),
            ],
          ),
        ),
        ShowcaseSection(
          title: '글자 — 토큰 스케일',
          note: '역할이 앉는 눈금. 역할이 이 밖의 크기를 새로 만들면 테스트가 잡는다.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final MapEntry(key: name, value: value)
                  in DropTokenTextSize.all.entries)
                _ScaleBar(name: name, value: value, colors: colors),
            ],
          ),
        ),
      ],
    );
  }
}

/// 사람이 tokens.json과 대조할 수 있는 형태로 적는다.
///
/// Dart의 ARGB를 그대로 뽑으면 불투명한 색이 전부 `#ff...`로 시작해서
/// 정본(`#d9730d`)과 눈으로 못 맞춘다. 알파는 실제로 반투명일 때만 뒤에 붙인다.
String _hex(Color color) {
  final argb = color.toARGB32();
  final rgb = (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
  final alpha = (argb >> 24) & 0xFF;
  return alpha == 0xFF
      ? '#$rgb'
      : '#$rgb${alpha.toRadixString(16).padLeft(2, '0')}';
}

class _Swatch extends StatelessWidget {
  final String name;
  final Color color;

  const _Swatch({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    final colors = DropColors.of(context);
    return SizedBox(
      width: 148,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: DropTokenSpace.x7,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(DropRadius.chip),
              // 투명·흰 색은 테두리가 없으면 배경에 녹아 사라진다.
              border: Border.all(color: colors.borderColor),
            ),
          ),
          const SizedBox(height: DropTokenSpace.x1),
          Text(
            name,
            style: DropText.meta.copyWith(color: colors.textPrimary),
          ),
          Text(
            _hex(color),
            style: DropText.caption.copyWith(
              color: colors.textTertiary,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class _ScaleBar extends StatelessWidget {
  final String name;
  final double value;
  final DropTokenColors colors;

  const _ScaleBar({
    required this.name,
    required this.value,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DropTokenSpace.x2),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              name,
              style: DropText.meta.copyWith(
                color: colors.textSecondary,
                fontFamily: 'monospace',
              ),
            ),
          ),
          Container(
            width: value,
            height: DropTokenSpace.x3,
            decoration: BoxDecoration(
              color: colors.accent,
              borderRadius: BorderRadius.circular(DropRadius.chip),
            ),
          ),
          const SizedBox(width: DropTokenSpace.x2),
          Text(
            value.toStringAsFixed(0),
            style: DropText.caption.copyWith(color: colors.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _RadiusChip extends StatelessWidget {
  final String name;
  final double value;
  final DropTokenColors colors;

  const _RadiusChip({
    required this.name,
    required this.value,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: DropTokenSpace.x8,
          height: DropTokenSpace.x8,
          decoration: BoxDecoration(
            color: colors.surfaceField,
            borderRadius: BorderRadius.circular(value),
            border: Border.all(color: colors.borderColor),
          ),
        ),
        const SizedBox(height: DropTokenSpace.x1),
        Text(name, style: DropText.caption.copyWith(color: colors.textSecondary)),
      ],
    );
  }
}

class _TypeRow extends StatelessWidget {
  final String name;
  final TextStyle style;
  final DropTokenColors colors;

  const _TypeRow({
    required this.name,
    required this.style,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DropTokenSpace.x3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$name · ${style.fontSize?.toStringAsFixed(0)}',
            style: DropText.caption.copyWith(
              color: colors.textTertiary,
              fontFamily: 'monospace',
            ),
          ),
          Text(
            '떠오르면 바로 던져넣기',
            style: style.copyWith(color: colors.textPrimary),
          ),
        ],
      ),
    );
  }
}
