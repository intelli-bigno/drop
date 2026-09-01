/// 쇼케이스 셸 (BRU-193). 데스크톱 `styleguide/index.tsx` 대응.
///
/// 좌측에 섹션 목록, 하단에 테마 전환. 앱(`DropApp`)과 **따로 사는 위젯**이다 —
/// 라우터·Riverpod·인증을 통째로 비켜 간다.
library;

import 'package:flutter/material.dart';

import '../theme/drop_theme.dart';
import 'sections/components.dart';
import 'sections/foundations.dart';
import 'sections/patterns.dart';
import 'sections/states.dart';

/// 진열 페이지 하나.
class ShowcasePage {
  final String id;
  final String label;
  final String hint;
  final WidgetBuilder build;

  const ShowcasePage({
    required this.id,
    required this.label,
    required this.hint,
    required this.build,
  });
}

const showcasePages = <ShowcasePage>[
  ShowcasePage(
    id: 'foundations',
    label: 'Foundations',
    hint: '토큰',
    build: _buildFoundations,
  ),
  ShowcasePage(
    id: 'components',
    label: 'Components',
    hint: '실물 위젯',
    build: _buildComponents,
  ),
  ShowcasePage(
    id: 'patterns',
    label: 'Patterns',
    hint: '목록의 규칙',
    build: _buildPatterns,
  ),
  ShowcasePage(
    id: 'states',
    label: 'States',
    hint: '빈·로딩·오류',
    build: _buildStates,
  ),
];

Widget _buildFoundations(BuildContext context) => const FoundationsSection();
Widget _buildComponents(BuildContext context) => const ComponentsSection();
Widget _buildPatterns(BuildContext context) => const PatternsSection();
Widget _buildStates(BuildContext context) => const StatesSection();

/// 테마 선택. `system`은 브라우저·OS 설정을 따른다.
enum ShowcaseTheme {
  system('시스템'),
  light('라이트'),
  dark('다크');

  final String label;
  const ShowcaseTheme(this.label);

  ThemeMode get mode => switch (this) {
        ShowcaseTheme.system => ThemeMode.system,
        ShowcaseTheme.light => ThemeMode.light,
        ShowcaseTheme.dark => ThemeMode.dark,
      };
}

class ShowcaseApp extends StatefulWidget {
  const ShowcaseApp({super.key});

  @override
  State<ShowcaseApp> createState() => _ShowcaseAppState();
}

class _ShowcaseAppState extends State<ShowcaseApp> {
  ShowcaseTheme _theme = ShowcaseTheme.system;
  int _pageIndex = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DROP 디자인 시스템',
      debugShowCheckedModeBanner: false,
      theme: DropTheme.light,
      darkTheme: DropTheme.dark,
      themeMode: _theme.mode,
      home: ShowcaseShell(
        pageIndex: _pageIndex,
        theme: _theme,
        onPage: (index) => setState(() => _pageIndex = index),
        onTheme: (theme) => setState(() => _theme = theme),
      ),
    );
  }
}

class ShowcaseShell extends StatelessWidget {
  final int pageIndex;
  final ShowcaseTheme theme;
  final ValueChanged<int> onPage;
  final ValueChanged<ShowcaseTheme> onTheme;

  const ShowcaseShell({
    super.key,
    required this.pageIndex,
    required this.theme,
    required this.onPage,
    required this.onTheme,
  });

  /// 좁은 창에서는 좌측 내비를 접는다 — 폰 표본(390)이 들어갈 자리부터 지킨다.
  static const double _navBreakpoint = 900;
  static const double _navWidth = 220;

  @override
  Widget build(BuildContext context) {
    final colors = DropColors.of(context);
    final isWide = MediaQuery.sizeOf(context).width >= _navBreakpoint;
    final page = showcasePages[pageIndex];

    return Scaffold(
      backgroundColor: colors.surfacePage,
      appBar: isWide
          ? null
          : AppBar(
              title: Text(page.label),
              actions: [_ThemeSwitch(theme: theme, onTheme: onTheme)],
            ),
      drawer: isWide
          ? null
          : Drawer(
              backgroundColor: colors.bgSecondary,
              child: SafeArea(
                child: _Nav(
                  pageIndex: pageIndex,
                  theme: theme,
                  onPage: (index) {
                    Navigator.of(context).pop();
                    onPage(index);
                  },
                  onTheme: onTheme,
                  showThemeSwitch: false,
                ),
              ),
            ),
      body: Row(
        children: [
          if (isWide)
            SizedBox(
              width: _navWidth,
              child: Container(
                color: colors.bgSecondary,
                child: SafeArea(
                  child: _Nav(
                    pageIndex: pageIndex,
                    theme: theme,
                    onPage: onPage,
                    onTheme: onTheme,
                    showThemeSwitch: true,
                  ),
                ),
              ),
            ),
          Expanded(
            // key를 페이지마다 갈아 끼워 스크롤 위치가 페이지 사이에 새지 않게 한다.
            child: KeyedSubtree(key: ValueKey(page.id), child: page.build(context)),
          ),
        ],
      ),
    );
  }
}

class _Nav extends StatelessWidget {
  final int pageIndex;
  final ShowcaseTheme theme;
  final ValueChanged<int> onPage;
  final ValueChanged<ShowcaseTheme> onTheme;
  final bool showThemeSwitch;

  const _Nav({
    required this.pageIndex,
    required this.theme,
    required this.onPage,
    required this.onTheme,
    required this.showThemeSwitch,
  });

  @override
  Widget build(BuildContext context) {
    final colors = DropColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(DropTokenSpace.x4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DROP 디자인 시스템',
                style: DropText.cardTitle.copyWith(color: colors.textPrimary),
              ),
              Text(
                'flutter · apps/mobile',
                style: DropText.caption.copyWith(color: colors.textTertiary),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              for (final (index, page) in showcasePages.indexed)
                _NavLink(
                  // 페이지 제목과 내비 이름이 같은 글자라, 테스트가 둘을 구분할
                  // 유일한 손잡이다.
                  key: ValueKey('showcase-nav-${page.id}'),
                  page: page,
                  isActive: index == pageIndex,
                  onTap: () => onPage(index),
                ),
            ],
          ),
        ),
        if (showThemeSwitch)
          Padding(
            padding: const EdgeInsets.all(DropTokenSpace.x3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '테마',
                  style: DropText.caption.copyWith(color: colors.textTertiary),
                ),
                const SizedBox(height: DropTokenSpace.x1),
                _ThemeSwitch(theme: theme, onTheme: onTheme),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            DropTokenSpace.x3,
            0,
            DropTokenSpace.x3,
            DropTokenSpace.x3,
          ),
          child: Text(
            '정본 · design-system/drop/tokens.json',
            style: DropText.caption.copyWith(color: colors.textMuted),
          ),
        ),
      ],
    );
  }
}

class _NavLink extends StatelessWidget {
  final ShowcasePage page;
  final bool isActive;
  final VoidCallback onTap;

  const _NavLink({
    super.key,
    required this.page,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = DropColors.of(context);
    return Material(
      color: isActive ? colors.surfaceSelected : colors.bgSecondary,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DropTokenSpace.x4,
            vertical: DropTokenSpace.x2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                page.label,
                style: DropText.body.copyWith(
                  color: isActive ? colors.accent : colors.textPrimary,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              Text(
                page.hint,
                style: DropText.caption.copyWith(color: colors.textTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeSwitch extends StatelessWidget {
  final ShowcaseTheme theme;
  final ValueChanged<ShowcaseTheme> onTheme;

  const _ThemeSwitch({required this.theme, required this.onTheme});

  @override
  Widget build(BuildContext context) {
    // SegmentedButton은 220px 내비에서 글자를 잘라먹는다("시스 템") — 실측으로
    // 확인하고 Wrap되는 칩으로 바꿨다. 좁아지면 줄로 흐르지 글자가 깨지지 않는다.
    return Wrap(
      spacing: DropTokenSpace.x1,
      runSpacing: DropTokenSpace.x1,
      children: [
        for (final choice in ShowcaseTheme.values)
          ChoiceChip(
            label: Text(choice.label),
            selected: theme == choice,
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
            onSelected: (_) => onTheme(choice),
          ),
      ],
    );
  }
}
