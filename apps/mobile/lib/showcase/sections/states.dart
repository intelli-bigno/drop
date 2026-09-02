/// States — 빈·로딩·오류 (BRU-193). 데스크톱 `styleguide/sections/States.tsx` 대응.
///
/// 이 페이지가 있어야 하는 이유: 이 상태들은 **평소에 안 보인다.** 빈 목록을 보려면
/// 계정에 노트가 하나도 없어야 하고, 오류를 보려면 네트워크를 끊어야 한다.
/// 그래서 손이 안 가고, 손이 안 가니 앱에서 가장 거친 자리로 남는다.
library;

import 'package:drop_core/drop_core.dart';
import 'package:flutter/material.dart';

import '../../theme/drop_theme.dart';
import '../../widgets/note_empty_state.dart';
import '../parts.dart';

class StatesSection extends StatelessWidget {
  const StatesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = DropColors.of(context);

    return ListView(
      padding: const EdgeInsets.all(DropTokenSpace.x5),
      children: [
        const PageHead(
          title: 'States',
          lede:
              '평소엔 안 보이는 자리들. 빈 목록·로딩·오류는 계정 상태나 네트워크를 '
              '망가뜨려야 볼 수 있어서 가장 손이 안 가는 곳이다.',
        ),
        for (final viewMode in NoteViewMode.values)
          Specimen(
            name: '빈 상태 — ${_viewModeLabel(viewMode)}',
            file: 'lib/widgets/note_empty_state.dart',
            phone: true,
            child: SizedBox(
              height: 160,
              child: Center(child: NoteEmptyState(viewMode: viewMode)),
            ),
          ),
        Specimen(
          name: '빈 상태 — 검색 결과 없음',
          desc: '검색 중이면 뷰 모드보다 검색이 이긴다',
          file: 'lib/widgets/note_empty_state.dart',
          phone: true,
          child: SizedBox(
            height: 160,
            child: Center(
              child: const NoteEmptyState(
                viewMode: NoteViewMode.trash,
                isSearching: true,
              ),
            ),
          ),
        ),
        Specimen(
          name: '로딩',
          desc: '첫 적재에만 나온다 — 새로고침은 당김 표시로 대신한다',
          file: 'lib/screens/home_screen.dart',
          phone: true,
          child: const SizedBox(
            height: 160,
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
        Specimen(
          name: '오류',
          desc:
              '앱이 실제로 쓰는 것 — 목록은 남기고 SnackBar로만 알린다. '
              '실패했다고 보던 것을 치우지 않는다',
          file: 'lib/screens/home_screen.dart',
          phone: true,
          // 쇼케이스용 배너를 새로 그리지 않는다 — 앱에 없는 물건을 진열하면
          // 쇼케이스가 앱보다 예뻐지고, 그 차이는 아무도 메우지 않는다.
          //
          // SnackBar는 단독으로 못 그린다(ScaffoldMessenger가 애니메이션을 쥔다).
          // 그래서 앱과 **같은 경로**로 띄운다 — 진열대가 진짜 기계를 돌린다.
          child: const _ErrorSnackBarSpecimen(),
        ),
        ShowcaseSection(
          title: '아직 없는 것',
          note:
              '쇼케이스를 지으면서 드러난 빈자리다. 진열할 물건이 없으므로 '
              '그리지 않고 적어만 둔다 — 없는 것을 그리면 있는 줄 안다.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final gap in const [
                '오프라인 상태 표시 — 지금은 실패한 요청마다 SnackBar만 뜬다',
                '첫 실행 안내 — 빈 상태가 "아직 노트가 없습니다" 한 줄뿐이다',
                '목록 하단 더 불러오기 — 페이지네이션 자체가 없다',
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: DropTokenSpace.x2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.remove,
                        size: DropIconSize.meta,
                        color: colors.textMuted,
                      ),
                      const SizedBox(width: DropTokenSpace.x2),
                      Expanded(
                        child: Text(
                          gap,
                          style: DropText.body.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static String _viewModeLabel(NoteViewMode mode) => switch (mode) {
    NoteViewMode.active => '노트',
    NoteViewMode.archived => '보관',
    NoteViewMode.trash => '휴지통',
  };
}

/// 오류 표본. 앱과 같은 경로(`ScaffoldMessenger.showSnackBar`)로 띄운다 —
/// 모양만 흉내 낸 배너를 그리면 앱이 실제로 어떻게 알리는지를 보여 주지 못한다.
class _ErrorSnackBarSpecimen extends StatelessWidget {
  const _ErrorSnackBarSpecimen();

  @override
  Widget build(BuildContext context) {
    final colors = DropColors.of(context);
    return SizedBox(
      height: 120,
      // 자기만의 Scaffold를 들어야 SnackBar가 이 칸 안에서 뜬다 —
      // 없으면 쇼케이스 창 맨 아래에 떠서 어느 표본의 것인지 알 수 없다.
      child: Scaffold(
        backgroundColor: colors.surfacePage,
        body: Center(
          child: Builder(
            builder: (context) => OutlinedButton.icon(
              icon: const Icon(Icons.error_outline, size: DropIconSize.control),
              label: const Text('오류 띄우기'),
              onPressed: () => ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('노트를 불러오지 못했습니다'))),
            ),
          ),
        ),
      ),
    );
  }
}
