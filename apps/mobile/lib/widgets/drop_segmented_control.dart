/// 세그먼트 컨트롤 — 배타적인 선택지 몇 개를 한 줄 트랙에 나란히 (BRU-207).
///
/// 카테고리(전체·링크·미디어·파일)처럼 **항상 하나는 켜져 있는** 선택에 쓴다.
/// 켜진 칸은 뒤집힌 면(글자색 바탕)이 미끄러져 옮겨 간다 — 칩 줄과 같은 문법이라
/// 화면에 "켜짐"의 표현이 하나뿐이다.
library;

import 'package:flutter/material.dart';

import '../theme/drop_theme.dart';
import 'drop_feedback.dart';

class DropSegmentedControl<T> extends StatelessWidget {
  final List<T> options;
  final T selected;
  final String Function(T option) labelOf;
  final ValueChanged<T> onChanged;

  const DropSegmentedControl({
    super.key,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
  });

  static const double _height = 40;
  static const double _inset = 3;

  @override
  Widget build(BuildContext context) {
    final colors = DropColors.of(context);
    final index = options.indexOf(selected);
    return Container(
      height: _height,
      padding: const EdgeInsets.all(_inset),
      decoration: BoxDecoration(
        color: colors.surfaceField,
        borderRadius: BorderRadius.circular(DropRadius.control),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth = constraints.maxWidth / options.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                left: segmentWidth * index,
                top: 0,
                bottom: 0,
                width: segmentWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surfaceInverse,
                    borderRadius: BorderRadius.circular(
                      DropRadius.control - _inset,
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final option in options)
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(
                          DropRadius.control - _inset,
                        ),
                        onTap: () {
                          if (option == selected) return;
                          DropHaptics.select();
                          onChanged(option);
                        },
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 160),
                            style: DropText.label.copyWith(
                              color: option == selected
                                  ? colors.onInverse
                                  : colors.textSecondary,
                            ),
                            child: Text(labelOf(option)),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
