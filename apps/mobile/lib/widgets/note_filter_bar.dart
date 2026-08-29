/// 카테고리·태그·검색이 한 줄에 사는 필터 줄. iOS `NoteFilterBar.swift` 대응.
///
/// **한 줄만 쓴다** (BRU-49) — 검색은 아이콘으로 접어 두었다가 누를 때만 펼치고,
/// 보기 전환(노트/보관/휴지통)은 상단 ⋯ 메뉴에 있다.
library;

import 'package:drop_core/drop_core.dart';
import 'package:flutter/material.dart';

import '../notes/notes_controller.dart';

class NoteFilterBar extends StatefulWidget {
  final NotesController controller;

  const NoteFilterBar({super.key, required this.controller});

  @override
  State<NoteFilterBar> createState() => _NoteFilterBarState();
}

class _NoteFilterBarState extends State<NoteFilterBar> {
  bool _isSearching = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 접을 때 질의를 비운다 — 보이지 않는 검색어가 목록을 계속 거르면
  /// 노트가 사라진 것처럼 보인다.
  void _toggleSearch() {
    setState(() => _isSearching = !_isSearching);
    if (!_isSearching) {
      _searchController.clear();
      widget.controller.setSearchText('');
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.controller.store;

    return SizedBox(
      height: 48,
      child: Row(
        children: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            tooltip: _isSearching ? '검색 닫기' : '검색',
            onPressed: _toggleSearch,
          ),
          if (_isSearching)
            Expanded(
              child: TextField(
                controller: _searchController,
                autofocus: true,
                autocorrect: false,
                decoration: const InputDecoration(
                  hintText: '노트 검색',
                  isDense: true,
                  border: InputBorder.none,
                ),
                onChanged: widget.controller.setSearchText,
              ),
            )
          else
            Expanded(
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(right: 16),
                children: [
                  for (final category in NoteCategory.values)
                    _chip(
                      label: _categoryLabel(category),
                      isOn: store.category == category,
                      onTap: () => widget.controller.setCategory(category),
                    ),
                  // 카테고리와 별도 축이다 (BRU-184) — 할일이면서 링크가 있는
                  // 노트가 있으므로 같은 배타 그룹에 넣을 수 없다.
                  _chip(
                    label: _todoLabel(store.todoFilter,
                        countOpenTodos(store.scopedNotes)),
                    isOn: store.todoFilter != TodoFilter.off,
                    onTap: widget.controller.cycleTodoFilter,
                  ),
                  if (store.availableTags.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: SizedBox(
                        height: 24,
                        child: VerticalDivider(width: 1),
                      ),
                    ),
                  for (final tag in store.availableTags)
                    _chip(
                      label: '#${tag.name}',
                      isOn: store.selectedTagId == tag.id,
                      onTap: () => widget.controller.toggleTag(tag.id),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool isOn,
    required VoidCallback onTap,
  }) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: Center(
      child: FilterChip(
        label: Text(label),
        selected: isOn,
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        onSelected: (_) => onTap(),
      ),
    ),
  );

  /// 숫자는 **남은** 할일만 센다. 목록은 "무엇을 했나"까지 보여 주지만 숫자는
  /// "얼마나 남았나"에 답해야 한다 — 두 질문이 다르므로 답도 다르다.
  String _todoLabel(TodoFilter filter, int openCount) => switch (filter) {
        TodoFilter.off => '할일 $openCount',
        TodoFilter.all => '할일 전체',
        TodoFilter.open => '남은 할일 $openCount',
      };

  String _categoryLabel(NoteCategory category) => switch (category) {
    NoteCategory.all => '전체',
    NoteCategory.links => '링크',
    NoteCategory.media => '미디어',
    NoteCategory.files => '파일',
  };
}
