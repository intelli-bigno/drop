/// 홈의 ⋯ 메뉴 — 보기 전환과 설정이 한 시트에 산다 (BRU-207).
///
/// 둘은 성격이 다르다: 보기(노트·보관·휴지통)는 "지금 어디를 볼까"라 고르면 시트가
/// 닫히며 화면이 바뀌고, 테마는 설정이라 고르면 **그 자리에서** 바뀌고 시트는 열린
/// 채로 결과를 보여 준다. 같은 세로 목록에 섞어 두었더니 성격이 뭉개졌다는 피드백을
/// 받아 구역을 나눴다 — 구역마다 이름표 하나, 세그먼트 하나.
library;

import 'package:drop_core/drop_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/drop_theme.dart';
import '../theme/theme_mode_controller.dart';
import '../widgets/drop_feedback.dart';
import '../widgets/drop_segmented_control.dart';

/// 시트가 돌려주는 것. 테마는 시트 안에서 바로 적용되므로 여기 없다.
sealed class HomeMenuChoice {
  const HomeMenuChoice();
}

class HomeMenuView extends HomeMenuChoice {
  final NoteViewMode mode;
  const HomeMenuView(this.mode);
}

class HomeMenuSignOut extends HomeMenuChoice {
  const HomeMenuSignOut();
}

Future<HomeMenuChoice?> showHomeMenuSheet(
  BuildContext context, {
  required NoteViewMode current,
  required bool isPreview,
}) => showModalBottomSheet<HomeMenuChoice>(
  context: context,
  useSafeArea: true,
  builder: (sheetContext) =>
      _HomeMenuSheet(current: current, isPreview: isPreview),
);

class _HomeMenuSheet extends ConsumerWidget {
  final NoteViewMode current;
  final bool isPreview;

  const _HomeMenuSheet({required this.current, required this.isPreview});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DropColors.of(context);
    final themeMode = ref.watch(themeModeProvider);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          DropLayout.gutter,
          0,
          DropLayout.gutter,
          DropTokenSpace.x3,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionLabel('보기', colors),
            DropSegmentedControl<NoteViewMode>(
              options: NoteViewMode.values,
              selected: current,
              labelOf: _viewLabel,
              onChanged: (mode) =>
                  Navigator.of(context).pop(HomeMenuView(mode)),
            ),
            const SizedBox(height: DropTokenSpace.x5),
            _SectionLabel('테마', colors),
            DropSegmentedControl<ThemeMode>(
              options: ThemeMode.values,
              selected: themeMode,
              labelOf: _themeLabel,
              onChanged: (mode) =>
                  ref.read(themeModeProvider.notifier).set(mode),
            ),
            if (!isPreview) ...[
              const SizedBox(height: DropTokenSpace.x5),
              const Divider(),
              InkWell(
                onTap: () {
                  DropHaptics.select();
                  Navigator.of(context).pop(const HomeMenuSignOut());
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: DropTokenSpace.x4,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.logout,
                        size: DropIconSize.action,
                        color: colors.textSecondary,
                      ),
                      const SizedBox(width: DropTokenSpace.x4),
                      Text(
                        '로그아웃',
                        style: DropText.cardTitle.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _viewLabel(NoteViewMode mode) => switch (mode) {
    NoteViewMode.active => '노트',
    NoteViewMode.archived => '보관',
    NoteViewMode.trash => '휴지통',
  };

  String _themeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.system => '시스템',
    ThemeMode.light => '라이트',
    ThemeMode.dark => '다크',
  };
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final DropTokenColors colors;

  const _SectionLabel(this.text, this.colors);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: DropTokenSpace.x2),
    child: Text(
      text,
      style: DropText.meta.copyWith(
        color: colors.textTertiary,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
