/// 디자인 시스템 계층의 약속 (BRU-193).
///
/// `design_system_audit_test.dart`가 "금지된 것을 안 썼나"를 소스로 훑는다면,
/// 이 파일은 "약속한 것이 실제로 그 값인가"를 값으로 확인한다. 둘 다 필요하다 —
/// 감사만 있으면 역할 이름이 엉뚱한 값을 들고 있어도 그린이다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/theme/drop_theme.dart';

void main() {
  group('DropText — 글자의 역할 이름', () {
    test('모든 역할의 크기는 토큰 스케일 위에 있다', () {
      // 토큰이 정한 6단이 전부. 역할이 그 사이의 값을 새로 만들면
      // 스케일이 스케일이기를 그만둔다.
      // const 집합으로 못 쓴다 — double은 const 집합이 요구하는
      // primitive equality가 없다.
      final scale = <double>{
        DropTokenTextSize.xs,
        DropTokenTextSize.sm,
        DropTokenTextSize.base,
        DropTokenTextSize.lg,
        DropTokenTextSize.xl,
        DropTokenTextSize.x2xl,
        DropTokenTextSize.x3xl,
      };

      for (final MapEntry(key: name, value: style) in DropText.roles.entries) {
        expect(
          scale.contains(style.fontSize),
          isTrue,
          reason: '$name의 크기 ${style.fontSize}는 토큰 스케일 밖이다',
        );
      }
    });

    test('역할은 색을 들지 않는다 — 색은 표면이 정한다', () {
      // 같은 body가 카드 위에서는 textPrimary, 메타 줄에서는 textSecondary다.
      // 역할이 색까지 쥐면 그 두 자리를 한 이름으로 못 쓴다.
      for (final MapEntry(key: name, value: style) in DropText.roles.entries) {
        expect(style.color, isNull, reason: '$name이 색을 들고 있다');
      }
    });

    test('본문보다 큰 역할은 굵고, 메타는 굵지 않다', () {
      expect(DropText.wordmark.fontWeight, FontWeight.w700);
      expect(DropText.screenTitle.fontWeight, FontWeight.w600);
      expect(DropText.sectionTitle.fontWeight, FontWeight.w600);
      expect(DropText.cardTitle.fontWeight, FontWeight.w600);
      expect(DropText.body.fontWeight, FontWeight.w400);
      expect(DropText.meta.fontWeight, FontWeight.w400);
      expect(DropText.caption.fontWeight, FontWeight.w400);
    });

    test('roles 지도가 실제 역할을 빠짐없이 담는다', () {
      // 지도가 곧 감사 대상이다 — 새 역할을 만들고 여기 안 넣으면
      // 위의 검사들이 그 역할을 그냥 지나친다.
      expect(
        DropText.roles.values,
        containsAll(<TextStyle>[
          DropText.wordmark,
          DropText.screenTitle,
          DropText.sectionTitle,
          DropText.cardTitle,
          DropText.body,
          DropText.meta,
          DropText.caption,
        ]),
      );
    });
  });

  group('DropSurfaces — 표면 역할', () {
    test('라이트·다크 모두에서 카드는 바탕과 구분된다', () {
      // 구분이 없으면 "떠 있는 종이"라는 뜻이 사라진다.
      for (final colors in [DropTokenColors.light, DropTokenColors.dark]) {
        expect(colors.surfaceCard, isNot(colors.surfacePage));
      }
    });
  });
}
