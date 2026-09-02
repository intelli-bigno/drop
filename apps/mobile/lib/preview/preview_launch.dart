/// 자격증명 없이 화면을 띄워 보기 위한 인메모리 표본.
/// iOS `Drop/PreviewLaunch.swift` 대응 — 표본 노트·댓글을 그대로 포팅했다.
///
/// `--dart-define=DROP_PREVIEW=true`로 실행하면 인증을 건너뛰고 이 데이터를 쓴다.
library;

import 'package:drop_core/drop_core.dart';

class PreviewLaunch {
  PreviewLaunch._();

  static InMemoryNotesRepository makeNotesRepository() =>
      InMemoryNotesRepository(notes: sampleNotes());

  /// 댓글 표본. 뱃지가 붙는 노트(1·2)와 하나도 없는 노트를 함께 둔다 —
  /// 0이면 뱃지를 그리지 않는다는 규칙을 눈으로 확인하기 위한 것이다.
  static InMemoryCommentsRepository makeCommentsRepository() =>
      InMemoryCommentsRepository(comments: sampleComments());

  static List<NoteComment> sampleComments() {
    final now = DateTime.now().toUtc();
    NoteComment comment(
      String id, {
      required String note,
      required String body,
      required double minutesAgo,
    }) {
      final at = now.subtract(
        Duration(milliseconds: (minutesAgo * 60 * 1000).round()),
      );
      return NoteComment(
        id: id,
        noteId: note,
        body: body,
        createdAt: at,
        updatedAt: at,
      );
    }

    return [
      comment('c1', note: '1', body: 'M3까지는 왔는데 위젯이 아직 남았다.', minutesAgo: 90),
      comment('c2', note: '1', body: '위젯은 BRU-35에서 따로 본다.', minutesAgo: 40),
      comment('c3', note: '1', body: '확인.', minutesAgo: 5),
      comment('c4', note: '2', body: '원두는 지난번 것으로.', minutesAgo: 30),
    ];
  }

  static List<Note> sampleNotes() {
    final now = DateTime.now().toUtc();
    Tag tag(String name) => Tag(id: name, name: name, createdAt: now);

    return [
      Note(
        id: '1',
        displayId: 12,
        content: 'iOS 네이티브 전환 M3 — 홈 화면까지 올라왔다.',
        tags: [tag('개발')],
        createdAt: now.subtract(const Duration(seconds: 120)),
        updatedAt: now,
        source: NoteSource.mobile,
        isPinned: true,
        pinnedAt: now,
        priority: 3,
      ),
      // 할일 표본 (BRU-207). 노트 단위 할일이 하나도 없으면 뷰어의 완료 토글도
      // 할일 필터도 눈으로 확인할 자리가 없다 — 화면이 못 보여 주는 상태는 방치된다.
      Note(
        id: 'todo-open',
        displayId: 21,
        content: '전세 계약서 특약 확인하기',
        tags: [tag('생활')],
        createdAt: now.subtract(const Duration(seconds: 1800)),
        updatedAt: now,
        source: NoteSource.mobile,
        type: NoteType.todo,
        priority: 2,
      ),
      Note(
        id: 'todo-done',
        displayId: 22,
        content: '리모델링 견적 세 곳 받기',
        createdAt: now.subtract(const Duration(seconds: 5400)),
        updatedAt: now,
        source: NoteSource.mobile,
        type: NoteType.todo,
        completedAt: now.subtract(const Duration(seconds: 600)),
        priority: 2,
      ),
      Note(
        id: '2',
        displayId: 11,
        content: '장보기: 우유, 커피 원두, 사과',
        tags: [tag('생활')],
        createdAt: now.subtract(const Duration(seconds: 3600)),
        updatedAt: now,
        source: NoteSource.desktop,
        priority: 2,
      ),
      // 계층 표본 (BRU-60). 답글은 자기 시각이 아니라 부모의 섹션에 붙어야 한다 —
      // 아래 두 답글은 부모("장보기", 1시간 전)보다 나중에 쓰였다.
      Note(
        id: '2-1',
        displayId: 17,
        content: '원두는 지난번 것으로',
        parentId: '2',
        createdAt: now.subtract(const Duration(seconds: 1800)),
        updatedAt: now,
        source: NoteSource.desktop,
      ),
      Note(
        id: '2-1-1',
        displayId: 18,
        content: '품절이면 다른 것도 괜찮다',
        parentId: '2-1',
        createdAt: now.subtract(const Duration(seconds: 900)),
        updatedAt: now,
        source: NoteSource.desktop,
      ),
      // 부모가 보관함에 있어 최상위로 올라오는 답글. 화살표 표시가 붙어야 한다.
      Note(
        id: '4-1',
        displayId: 19,
        content: '회고에서 나온 후속 — 부모는 보관함에 있다',
        parentId: '4',
        createdAt: now.subtract(const Duration(seconds: 7200)),
        updatedAt: now,
        source: NoteSource.desktop,
      ),
      // 한 줄로 줄인 뒤에도 긴 본문이 줄을 밀지 않는지 눈으로 보기 위한 표본.
      Note(
        id: '6',
        displayId: 14,
        content:
            '긴 본문은 한 줄에서 잘려야 한다 — 목록은 훑는 자리이고 다 읽는 자리는 컴포저다. '
            '이 문장이 두 줄로 내려가면 한 화면에 들어오는 노트 수가 다시 줄어든다.',
        tags: [tag('설계'), tag('iOS'), tag('BRU-49')],
        createdAt: now.subtract(const Duration(seconds: 5400)),
        updatedAt: now,
        source: NoteSource.desktop,
        priority: 1,
      ),
      // 마크다운 표본 (BRU-37). 목록에서는 기호가 걷힌 한 줄로 보이고,
      // 컴포저의 미리보기에서 제목·목록·체크박스·코드·인용·링크가 서야 한다.
      Note(
        id: '9',
        displayId: 20,
        content:
            '# 이번 주 정리\n'
            '\n'
            '**굵게**와 *기울임*, 그리고 `인라인 코드`.\n'
            '\n'
            '- [x] 파서를 DropCore에 두기\n'
            '- [ ] 뷰어 붙이기\n'
            '  - 목록 안의 목록\n'
            '- [ ] 편집기 툴바\n'
            '\n'
            '1. 첫째\n'
            '2. 둘째\n'
            '\n'
            '> 저장 형식은 평문 마크다운 그대로다.\n'
            '\n'
            '```swift\n'
            'let document = MarkdownParser().parse(note.content)\n'
            '```\n'
            '\n'
            '---\n'
            '\n'
            '[이슈 보기](https://linear.app/intellieffect/issue/BRU-37)',
        tags: [tag('설계')],
        createdAt: now.subtract(const Duration(seconds: 300)),
        updatedAt: now,
        source: NoteSource.desktop,
        priority: 2,
      ),
      Note(
        id: '7',
        displayId: 15,
        content: '어제 적어 둔 메모',
        createdAt: now.subtract(const Duration(seconds: 100000)),
        updatedAt: now,
        source: NoteSource.mobile,
      ),
      Note(
        id: '8',
        displayId: 16,
        content: '사흘 전 링크',
        createdAt: now.subtract(const Duration(seconds: 260000)),
        updatedAt: now,
        source: NoteSource.web,
        hasLink: true,
      ),
      Note(
        id: '5',
        displayId: 13,
        content: '제주 사진 몇 장',
        attachments: [
          for (var index = 1; index <= 3; index++)
            Attachment(
              id: 'img$index',
              noteId: '5',
              type: AttachmentType.image,
              storagePath: 'u/5/img$index.png',
              filename: 'img$index.png',
              mimeType: 'image/png',
              size: 240000,
              createdAt: now,
            ),
        ],
        tags: [tag('사진')],
        createdAt: now.subtract(const Duration(seconds: 600)),
        updatedAt: now,
        source: NoteSource.mobile,
        hasMedia: true,
      ),
      Note(
        id: '3',
        displayId: 10,
        content: '회의 녹음',
        attachments: [
          Attachment(
            id: 'a1',
            noteId: '3',
            type: AttachmentType.audio,
            storagePath: 'u/3/a1.m4a',
            filename: 'a1.m4a',
            mimeType: 'audio/m4a',
            size: 1536000,
            createdAt: now,
          ),
        ],
        createdAt: now.subtract(const Duration(seconds: 90000)),
        updatedAt: now,
        source: NoteSource.mcp,
        hasMedia: true,
      ),
      Note(
        id: '4',
        displayId: 9,
        content: '보관해 둔 지난 분기 회고',
        createdAt: now.subtract(const Duration(seconds: 400000)),
        updatedAt: now,
        source: NoteSource.web,
        archivedAt: now.subtract(const Duration(seconds: 100000)),
      ),
      // 휴지통 뷰(BRU-156)를 눈으로 확인하기 위한 표본.
      Note(
        id: '10',
        displayId: 8,
        content: '버린 초안 — 휴지통에서만 보인다',
        createdAt: now.subtract(const Duration(seconds: 500000)),
        updatedAt: now,
        source: NoteSource.mobile,
        deletedAt: now.subtract(const Duration(seconds: 50000)),
        isDeleted: true,
      ),
    ];
  }
}
