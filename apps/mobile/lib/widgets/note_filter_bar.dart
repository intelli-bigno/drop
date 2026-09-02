/// 목록 머리의 조작 세 줄 — 검색 · 카테고리 · 필터. iOS `NoteFilterBar.swift` 대응.
///
/// BRU-49의 "한 줄" 원칙을 BRU-207에서 접었다: 검색을 아이콘 뒤에 접어 두고
/// 카테고리·할일·태그를 한 줄에 섞으니 무엇이 무엇인지 읽히지 않았다(사용자 피드백).
/// 이제 줄마다 하나의 질문만 한다 —
///   1. 무엇을 찾나 (검색창, 항상 보인다)
///   2. 어떤 종류인가 (카테고리 세그먼트, 항상 하나가 켜져 있다)
///   3. 더 좁힐까 (할일·태그 알약, 켜고 끌 수 있다)
library;

import 'package:drop_core/drop_core.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../notes/notes_controller.dart';
import '../theme/drop_theme.dart';
import 'drop_feedback.dart';
import 'drop_segmented_control.dart';

class NoteFilterBar extends StatefulWidget {
  final NotesController controller;

  const NoteFilterBar({super.key, required this.controller});

  @override
  State<NoteFilterBar> createState() => _NoteFilterBarState();
}

class _NoteFilterBarState extends State<NoteFilterBar> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _stripController = ScrollController();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _stripController.dispose();
    super.dispose();
  }

  void _search(String text) {
    widget.controller.setSearchText(text);
    setState(() {}); // 지우기 버튼의 유무가 글자 유무를 따른다.
  }

  void _clearSearch() {
    DropHaptics.select();
    _searchController.clear();
    _search('');
    _searchFocus.unfocus();
  }

  /// 할일이 하나도 없을 때 할일 필터를 켜면 목록이 통째로 비어 "고장"으로 읽힌다.
  /// 그때는 돌리지 않고 무엇을 하면 되는지만 말한다.
  void _tapTodo(NotesStore store) {
    final hasTodos = store.scopedNotes.any((note) => note.isTodo);
    if (!hasTodos && store.todoFilter == TodoFilter.off) {
      showDropToast(context, '할일이 없어요. 툴바의 체크박스로 만들 수 있어요');
      return;
    }
    widget.controller.cycleTodoFilter();
  }

  /// 마우스 휠은 세로로만 온다 — 가로 칩 줄에서는 그 힘을 옆으로 돌린다.
  void _wheel(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_stripController.hasClients) return;
    final position = _stripController.position;
    final delta = event.scrollDelta.dy.abs() > event.scrollDelta.dx.abs()
        ? event.scrollDelta.dy
        : event.scrollDelta.dx;
    _stripController.jumpTo(
      (position.pixels + delta).clamp(0.0, position.maxScrollExtent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.controller.store;
    final colors = DropColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            DropLayout.gutter,
            DropTokenSpace.x1,
            DropLayout.gutter,
            DropTokenSpace.x3,
          ),
          child: _searchField(colors),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DropLayout.gutter),
          child: DropSegmentedControl<NoteCategory>(
            options: NoteCategory.values,
            selected: store.category,
            labelOf: _categoryLabel,
            onChanged: widget.controller.setCategory,
          ),
        ),
        const SizedBox(height: DropTokenSpace.x3),
        SizedBox(
          height: DropLayout.chipHeight,
          child: _chipStrip(store, colors),
        ),
        const SizedBox(height: DropTokenSpace.x2),
      ],
    );
  }

  /// 검색창. 치는 대로 거르고, 오른쪽 동그란 버튼은 키보드를 내리며 "찾기"를 확정한다.
  Widget _searchField(DropTokenColors colors) {
    final hasText = _searchController.text.isNotEmpty;
    return Container(
      height: 44,
      padding: const EdgeInsets.only(
        left: DropTokenSpace.x4,
        right: DropTokenSpace.x1,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceField,
        borderRadius: BorderRadius.circular(DropRadius.control),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              autocorrect: false,
              textInputAction: TextInputAction.search,
              style: DropText.body.copyWith(color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: '노트 검색',
                hintStyle: DropText.body.copyWith(color: colors.textMuted),
              ),
              onChanged: _search,
              onSubmitted: (_) => _searchFocus.unfocus(),
            ),
          ),
          if (hasText)
            IconButton(
              tooltip: '검색 지우기',
              icon: const Icon(Icons.cancel),
              iconSize: DropIconSize.control,
              color: colors.textMuted,
              onPressed: _clearSearch,
            ),
          DropPill(
            icon: Icons.search,
            tooltip: '검색',
            isOn: hasText,
            onTap: () {
              if (hasText) {
                _searchFocus.unfocus();
              } else {
                _searchFocus.requestFocus();
              }
            },
          ),
        ],
      ),
    );
  }

  /// 오른쪽 끝을 바탕색으로 녹인다 — 잘린 칩이 "깨진 것"이 아니라 "더 있다"로 읽히게.
  Widget _chipStrip(NotesStore store, DropTokenColors colors) => Listener(
    onPointerSignal: _wheel,
    child: ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: [
          colors.surfacePage,
          colors.surfacePage,
          colors.surfacePage.withValues(alpha: 0),
        ],
        stops: const [0, 0.92, 1],
      ).createShader(bounds),
      blendMode: BlendMode.dstIn,
      child: ListView(
        controller: _stripController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(
          left: DropLayout.gutter,
          right: DropLayout.gutter * 2,
        ),
        children: [
          // 카테고리와 별도 축이다 (BRU-184) — 할일이면서 링크가 있는
          // 노트가 있으므로 같은 배타 그룹에 넣을 수 없다.
          _chip(
            label: _todoLabel(
              store.todoFilter,
              countOpenTodos(store.scopedNotes),
            ),
            icon: Icons.check_circle_outline,
            isOn: store.todoFilter != TodoFilter.off,
            isMuted: !store.scopedNotes.any((note) => note.isTodo),
            onTap: () => _tapTodo(store),
          ),
          if (store.availableTags.isNotEmpty)
            const SizedBox(width: DropTokenSpace.x2),
          for (final tag in store.availableTags)
            _chip(
              label: '#${tag.name}',
              isOn: store.selectedTagId == tag.id,
              onTap: () => widget.controller.toggleTag(tag.id),
            ),
        ],
      ),
    ),
  );

  Widget _chip({
    required String label,
    IconData? icon,
    required bool isOn,
    bool isMuted = false,
    required VoidCallback onTap,
  }) => Padding(
    padding: const EdgeInsets.only(right: DropTokenSpace.x2),
    child: DropPill(
      label: label,
      icon: icon,
      isOn: isOn,
      isMuted: isMuted,
      onTap: onTap,
    ),
  );

  /// 꺼짐: 남은 개수(0이면 숫자 없이). 켜짐: 어떤 할일을 보는 중인지 —
  /// 라벨은 "할일"로 시작해 자리를 지키고, 뒤에 붙는 말만 바뀐다.
  String _todoLabel(TodoFilter filter, int openCount) => switch (filter) {
    TodoFilter.off => openCount > 0 ? '할일 $openCount' : '할일',
    TodoFilter.all => '할일 · 전체',
    TodoFilter.open => '할일 · 남은 $openCount',
  };

  String _categoryLabel(NoteCategory category) => switch (category) {
    NoteCategory.all => '전체',
    NoteCategory.links => '링크',
    NoteCategory.media => '미디어',
    NoteCategory.files => '파일',
  };
}

/// 알약 — 필터 칩과 동그란 아이콘 버튼이 같은 물건이다.
///
/// 켜짐은 색을 더하는 게 아니라 면을 **뒤집는다**(글자색 바탕 + 바탕색 글자).
/// 꺼짐은 눌러 넣은 면(surfaceField). 테두리는 없다. 켜고 끌 때 면·글자색이
/// 미끄러지듯 바뀐다 — 툭 바뀌면 "눌렸나?"가 된다.
class DropPill extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final String? tooltip;
  final bool isOn;

  /// 지금은 할 게 없는 칩 — 눌리긴 하지만 흐리게 서서 기대를 낮춘다.
  final bool isMuted;
  final VoidCallback onTap;

  const DropPill({
    super.key,
    this.label,
    this.icon,
    this.tooltip,
    required this.isOn,
    this.isMuted = false,
    required this.onTap,
  }) : assert(label != null || icon != null);

  @override
  Widget build(BuildContext context) {
    final colors = DropColors.of(context);
    final foreground = isOn
        ? colors.onInverse
        : isMuted
        ? colors.textMuted
        : colors.textSecondary;
    final iconOnly = label == null;
    final pill = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      decoration: ShapeDecoration(
        color: isOn ? colors.surfaceInverse : colors.surfaceField,
        shape: const StadiumBorder(),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () {
          DropHaptics.select();
          onTap();
        },
        // 뒤집힌 면 위에서는 바탕색을, 보통 면 위에서는 글자색을 옅게 깐다 —
        // 어느 쪽이든 마우스가 올라온 것이 한눈에 보여야 한다.
        hoverColor: isOn
            ? colors.onInverse.withValues(alpha: 0.16)
            : colors.surfaceHover,
        highlightColor: isOn
            ? colors.onInverse.withValues(alpha: 0.26)
            : colors.surfacePressed,
        child: SizedBox(
          height: DropLayout.chipHeight,
          width: iconOnly ? DropLayout.chipHeight : null,
          child: Padding(
            padding: EdgeInsets.only(
              left: iconOnly
                  ? 0
                  : (icon == null ? DropTokenSpace.x4 : DropTokenSpace.x3),
              right: iconOnly ? 0 : DropTokenSpace.x4,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null)
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    child: Icon(
                      icon,
                      key: ValueKey(icon),
                      size: iconOnly
                          ? DropIconSize.control
                          : DropIconSize.inline + 2,
                      color: foreground,
                    ),
                  ),
                if (!iconOnly) ...[
                  if (icon != null)
                    const SizedBox(width: DropTokenSpace.x1 + 2),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 160),
                    style: DropText.label.copyWith(color: foreground),
                    child: Text(label!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    if (tooltip == null) return pill;
    return Tooltip(message: tooltip!, child: pill);
  }
}
