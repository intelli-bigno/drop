/// 태그 목록·필터 화면. iOS `Drop/TagsView.swift` 대응.
///
/// 태그별 노트 수는 이미 받아 둔 목록에서 세면 되므로 별도 쿼리를 쓰지 않는다.
library;

import 'package:drop_core/drop_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../environment/providers.dart';
import '../theme/drop_theme.dart';

/// 한 행이 그릴 것 — 태그와, 그 태그가 붙은 **활성** 노트 수.
typedef TagCount = ({Tag tag, int count});

/// iOS `TagsView.tagCounts` 포팅: 활성 노트만 세고, 많이 쓰인 순으로 정렬.
/// 위젯 밖의 순수 함수로 둬서 트리를 띄우지 않고도 시험한다.
List<TagCount> tagCounts(NotesStore store) {
  final counts = <String, int>{};
  for (final note in store.allNotes.where((note) => note.isActive)) {
    for (final tag in note.tags) {
      counts.update(tag.id, (count) => count + 1, ifAbsent: () => 1);
    }
  }
  return store.availableTags
      .map((tag) => (tag: tag, count: counts[tag.id] ?? 0))
      .toList()
    ..sort((a, b) => b.count.compareTo(a.count));
}

class TagsScreen extends ConsumerWidget {
  /// 목록 상태의 스코프 키 — 홈과 같은 `NotesController`를 본다.
  final String? userId;

  const TagsScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(notesControllerProvider(userId));
    final store = notes.store;
    final colors = DropColors.of(context);
    final entries = tagCounts(store);

    return Scaffold(
      appBar: AppBar(
        title: const Text('태그'),
        actions: [
          if (store.selectedTagId != null)
            TextButton(
              onPressed: () => notes.selectTag(null),
              child: Text('필터 해제',
                  style: TextStyle(color: colors.accent)),
            ),
        ],
      ),
      body: entries.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tag, size: 48, color: colors.textMuted),
                  const SizedBox(height: DropSpacing.base),
                  Text(
                    '태그가 없습니다',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: DropTokenTextSize.lg,
                    ),
                  ),
                ],
              ),
            )
          : ListView.separated(
              itemCount: entries.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final entry = entries[index];
                final isSelected = store.selectedTagId == entry.tag.id;
                return ListTile(
                  tileColor: isSelected ? colors.surfaceSelected : null,
                  title: Text(
                    '#${entry.tag.name}',
                    style: TextStyle(color: colors.textPrimary),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${entry.count}',
                        style: TextStyle(color: colors.textSecondary),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: DropSpacing.base),
                        Icon(Icons.check, size: 18, color: colors.accent),
                      ],
                    ],
                  ),
                  onTap: () => notes.selectTag(entry.tag.id),
                );
              },
            ),
    );
  }
}
