/// 쇼케이스가 **자기 자신을 그리는 데** 쓰는 조각들 (BRU-193).
/// 데스크톱 `styleguide/parts.tsx` 대응.
///
/// 여기 있는 것은 진열대다 — 진열되는 물건은 `lib/widgets`·`lib/screens`에 있다.
/// 이 구분이 흐려지면 쇼케이스에서만 예쁜 컴포넌트가 태어난다.
library;

import 'package:flutter/material.dart';

import '../theme/drop_theme.dart';

/// 폰 화면의 논리 너비. 모바일 위젯을 브라우저 전폭에 늘어놓으면
/// 실제로 보일 모습과 달라져 쇼케이스가 쓸모를 잃는다 — 폰 너비로 가둔다.
const double phoneWidth = 390;

class PageHead extends StatelessWidget {
  final String title;
  final String? lede;

  const PageHead({super.key, required this.title, this.lede});

  @override
  Widget build(BuildContext context) {
    final colors = DropColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: DropTokenSpace.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: DropText.screenTitle.copyWith(color: colors.textPrimary),
          ),
          if (lede != null) ...[
            const SizedBox(height: DropTokenSpace.x2),
            Text(
              lede!,
              style: DropText.body.copyWith(color: colors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class ShowcaseSection extends StatelessWidget {
  final String title;
  final String? note;
  final Widget child;

  const ShowcaseSection({
    super.key,
    required this.title,
    this.note,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = DropColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: DropTokenSpace.x6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: DropText.sectionTitle.copyWith(color: colors.textPrimary),
          ),
          if (note != null) ...[
            const SizedBox(height: DropTokenSpace.x1),
            Text(
              note!,
              style: DropText.meta.copyWith(color: colors.textTertiary),
            ),
          ],
          const SizedBox(height: DropTokenSpace.x3),
          child,
        ],
      ),
    );
  }
}

/// 표본 한 칸.
///
/// `file`은 진열된 물건이 **실제로 사는 곳**이다 — 쇼케이스에서 뭔가를 보고
/// 코드로 가려면 그 경로가 있어야 한다. 데스크톱 `Specimen`의 같은 자리.
class Specimen extends StatelessWidget {
  final String name;
  final String? desc;
  final String? file;

  /// 표본을 폰 너비로 가둘지. 위젯(노트 행·필터 줄)은 참, 색 견본은 거짓.
  final bool phone;
  final Widget child;

  const Specimen({
    super.key,
    required this.name,
    this.desc,
    this.file,
    this.phone = false,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = DropColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: DropTokenSpace.x4),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(DropRadius.card),
        border: Border.all(color: colors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(DropTokenSpace.x3),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: DropTokenSpace.x2,
              runSpacing: DropTokenSpace.x1,
              children: [
                Text(
                  name,
                  style: DropText.cardTitle.copyWith(color: colors.textPrimary),
                ),
                if (desc != null)
                  Text(
                    desc!,
                    style: DropText.meta.copyWith(color: colors.textSecondary),
                  ),
                if (file != null) _FilePath(file!),
              ],
            ),
          ),
          Divider(height: 1, color: colors.borderSubtle),
          Padding(
            padding: const EdgeInsets.all(DropTokenSpace.x3),
            // 표본 바탕은 카드가 아니라 **앱 바탕**이어야 한다 — 노트 행은
            // 앱 바탕 위에 앉는 물건이라 카드 위에 얹으면 대비가 거짓이 된다.
            //
            // phone일 때 바탕을 화면 전폭으로 늘리지 않는다. 폰 위젯이 광활한
            // 바탕 한가운데 떠 있으면 여백 감각이 실제와 완전히 달라진다 —
            // 바탕 자체를 폰 너비로 자른다.
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: phone ? phoneWidth : double.infinity,
                decoration: BoxDecoration(
                  color: colors.surfacePage,
                  borderRadius: BorderRadius.circular(DropRadius.row),
                  border: phone ? Border.all(color: colors.borderSubtle) : null,
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: DropTokenSpace.x2,
                ),
                // stretch가 없으면 자식이 제 글자 너비로 쪼그라들어 가운데로
                // 몰린다 — 섹션 머리글이 실제로 그렇게 가운데 정렬됐다(실측).
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [child],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilePath extends StatelessWidget {
  final String path;

  const _FilePath(this.path);

  @override
  Widget build(BuildContext context) {
    final colors = DropColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DropTokenSpace.x2,
        vertical: DropTokenSpace.x1,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceField,
        borderRadius: BorderRadius.circular(DropRadius.chip),
      ),
      child: Text(
        path,
        style: DropText.caption.copyWith(
          color: colors.textTertiary,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}
