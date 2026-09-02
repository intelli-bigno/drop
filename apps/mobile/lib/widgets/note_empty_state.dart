/// 목록이 빌 때 그 자리에 서는 것 (BRU-193에서 HomeScreen 밖으로 꺼냄).
///
/// 아이콘 없이 **말로만** 선다 — 큰 회색 아이콘은 "여기 아무것도 없다"를
/// 두 번 말하는 셈이라 뺐다. 첫 줄이 상태, 둘째 줄이 다음에 할 일이다.
library;

import 'package:drop_core/drop_core.dart';
import 'package:flutter/material.dart';

import '../theme/drop_theme.dart';

class NoteEmptyState extends StatelessWidget {
  final NoteViewMode viewMode;

  /// 검색 중이면 뷰 모드보다 검색이 이긴다 — "휴지통이 비어 있습니다"는
  /// 검색어를 지우면 결과가 나온다는 사실을 숨긴다.
  final bool isSearching;

  /// 카테고리·할일·태그 필터가 켜져 있으면 "노트가 없다"가 아니라 "이 조건에 맞는
  /// 노트가 없다"다 — 앞 문장은 사용자가 방금 켠 필터를 잊게 만든다 (BRU-207 실사고:
  /// 할일 0개인 표본에서 할일 필터를 켜자 첫 노트를 쓰라는 안내가 떴다).
  final bool isFiltered;

  /// "남은 할일"만 보는 중인데 비었다 — 이건 문제가 아니라 다 끝낸 것이다.
  final bool isAllDone;

  const NoteEmptyState({
    super.key,
    required this.viewMode,
    this.isSearching = false,
    this.isFiltered = false,
    this.isAllDone = false,
  });

  String get message => isSearching
      ? '검색 결과가 없습니다'
      : isAllDone
      ? '남은 할일이 없습니다'
      : isFiltered
      ? '조건에 맞는 노트가 없습니다'
      : switch (viewMode) {
          NoteViewMode.active => '아직 노트가 없습니다',
          NoteViewMode.archived => '보관한 노트가 없습니다',
          NoteViewMode.trash => '휴지통이 비어 있습니다',
        };

  /// 다음에 할 일. 빈 화면은 막다른 골목이 아니라 안내판이어야 한다.
  String? get hint => isSearching
      ? '다른 말로 다시 찾아보세요'
      : isAllDone
      ? '다 끝냈어요. 할일 칩을 다시 누르면 전체 노트로 돌아가요'
      : isFiltered
      ? '위의 필터를 풀면 다시 보여요'
      : switch (viewMode) {
          NoteViewMode.active => '떠오르면 아래 + 로 바로 던져 넣으세요',
          NoteViewMode.archived => '노트를 길게 눌러 보관할 수 있어요',
          NoteViewMode.trash => null,
        };

  IconData get icon => switch (viewMode) {
    NoteViewMode.active => Icons.inbox_outlined,
    NoteViewMode.archived => Icons.archive_outlined,
    NoteViewMode.trash => Icons.delete_outline,
  };

  @override
  Widget build(BuildContext context) {
    final colors = DropColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DropLayout.gutter),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: DropText.cardTitle.copyWith(color: colors.textPrimary),
          ),
          if (hint != null) ...[
            const SizedBox(height: DropTokenSpace.x2),
            Text(
              hint!,
              textAlign: TextAlign.center,
              style: DropText.body.copyWith(color: colors.textTertiary),
            ),
          ],
        ],
      ),
    );
  }
}
