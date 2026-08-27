/// 노트 뷰어 **플레이스홀더** — 읽기 전용 (BRU-77의 탭 계약을 지키는 최소한).
/// 진짜 뷰어(마크다운 렌더·댓글·상태 액션)는 BRU-157이 이 화면을 갈아끼운다.
/// 라우트(`/note/:id`) 배선은 그대로 쓴다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../environment/providers.dart';

class NoteDetailScreen extends ConsumerWidget {
  final String noteId;

  /// 목록과 같은 컨트롤러를 보는 스코프 키. 홈이 라우트 extra로 넘긴다.
  final String? userId;

  const NoteDetailScreen({super.key, required this.noteId, this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(notesControllerProvider(userId));
    // 노트를 통째로 들고 있으면 편집 저장 뒤에도 옛 값이 남는다 —
    // id만 들고 목록에서 매번 찾는다 (BRU-77과 같은 태도).
    final matches = notes.store.allNotes
        .where((note) => note.id == noteId)
        .toList();
    final note = matches.isEmpty ? null : matches.first;

    return Scaffold(
      appBar: AppBar(title: Text(note == null ? '노트' : '#${note.displayId}')),
      body: note == null
          ? const Center(child: Text('노트를 찾을 수 없습니다'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectableText(note.content),
            ),
    );
  }
}
