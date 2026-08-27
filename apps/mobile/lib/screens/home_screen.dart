/// 홈 플레이스홀더 — 노트 목록이 컨테이너를 통해 흐르는지 보이는 최소한.
///
/// 진짜 피드(행 디자인·계층·필터)는 BRU-156이다. 그쪽 작업은 이 위젯을
/// 갈아끼우면 되고, 배선(컨테이너 → NotesStore → 화면)은 그대로 쓴다.
library;

import 'package:drop_core/drop_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../environment/providers.dart';

class HomeScreen extends ConsumerWidget {
  /// 목록 상태의 스코프 키. 사용자가 바뀌면 목록도 처음부터 다시 만든다.
  final String? userId;

  const HomeScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final container = ref.watch(dropContainerProvider);
    final notes = ref.watch(notesControllerProvider(userId));
    final store = notes.store;

    return Scaffold(
      appBar: AppBar(
        title: const Text('DROP'),
        actions: [
          if (!container.isPreview)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: '로그아웃',
              onPressed: () => ref.read(authControllerProvider).signOut(),
            ),
        ],
      ),
      body: _body(store),
    );
  }

  Widget _body(NotesStore store) {
    final errorMessage = store.errorMessage;
    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(errorMessage, textAlign: TextAlign.center),
        ),
      );
    }
    if (store.isLoading && store.allNotes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final now = DateTime.now();
    final rows = store.visibleNotes;
    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final note = rows[index];
        return ListTile(
          title: Text(
            note.content,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(relativeTimeString(note.createdAt, now: now)),
        );
      },
    );
  }
}
