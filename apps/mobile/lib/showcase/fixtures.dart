/// 쇼케이스가 진열할 표본 데이터 (BRU-193). 데스크톱 `styleguide/fixtures.ts` 대응.
///
/// 서버를 타지 않는다 — 쇼케이스는 로그인도 Supabase도 없이 떠야 하고,
/// 그래야 "지금 내 계정에 그런 노트가 없어서" 못 보는 상태가 사라진다.
///
/// 표본은 **어려운 경우**를 고른다. 예쁜 한 줄만 늘어놓으면 쇼케이스가
/// 실제로 깨지는 자리(긴 제목·빈 본문·깊은 답글)를 못 보여 준다.
library;

import 'package:drop_core/drop_core.dart';

/// 시각이 흐르면 상대시간 표시("3분 전")가 매번 달라져 스크린샷 비교가 안 된다 —
/// 고정 기준시각에서 거꾸로 뺀다.
final DateTime showcaseNow = DateTime(2026, 8, 30, 14, 0);

Note _note({
  required String id,
  required int displayId,
  required String content,
  Duration age = Duration.zero,
  String? parentId,
  List<Tag> tags = const [],
  List<Attachment> attachments = const [],
  bool isPinned = false,
  bool hasLink = false,
  NoteType type = NoteType.note,
  Duration? completedAgo,
}) {
  final createdAt = showcaseNow.subtract(age);
  return Note(
    id: id,
    displayId: displayId,
    content: content,
    parentId: parentId,
    tags: tags,
    attachments: attachments,
    createdAt: createdAt,
    updatedAt: createdAt,
    source: NoteSource.mobile,
    isPinned: isPinned,
    pinnedAt: isPinned ? createdAt : null,
    hasLink: hasLink,
    hasMedia: attachments.any((a) => a.isImage),
    type: type,
    completedAt: completedAgo == null
        ? null
        : showcaseNow.subtract(completedAgo),
  );
}

final Tag tagRead = Tag(id: 'tag-read', name: '읽을거리', createdAt: showcaseNow);
final Tag tagWork = Tag(id: 'tag-work', name: '일', createdAt: showcaseNow);
final Tag tagIdea = Tag(id: 'tag-idea', name: '아이디어', createdAt: showcaseNow);

final List<Tag> showcaseTags = [tagRead, tagWork, tagIdea];

final Attachment showcaseImage = Attachment(
  id: 'att-1',
  noteId: 'note-media',
  type: AttachmentType.image,
  storagePath: 'showcase/sample.png',
  filename: 'sample.png',
  createdAt: showcaseNow,
);

final Attachment showcaseFile = Attachment(
  id: 'att-2',
  noteId: 'note-media',
  type: AttachmentType.file,
  storagePath: 'showcase/spec.pdf',
  filename: 'spec.pdf',
  createdAt: showcaseNow,
);

/// 진열용 노트들. 이름이 곧 "어떤 어려운 경우인가"다.
final Note noteShort = _note(
  id: 'note-short',
  displayId: 1,
  content: '장보기 — 우유, 커피 원두',
  age: const Duration(minutes: 8),
);

final Note noteLong = _note(
  id: 'note-long',
  displayId: 2,
  content:
      '한 줄에 다 못 들어가는 긴 노트. 목록에서는 말줄임으로 잘리고 뷰어에서는 '
      '전문이 보여야 한다 — 두 자리의 규칙이 다르다는 것을 쇼케이스가 보여 줘야 '
      '한다. 이 문장이 그 자리를 만든다.',
  age: const Duration(hours: 3),
  tags: [tagRead],
);

final Note notePinned = _note(
  id: 'note-pinned',
  displayId: 3,
  content: '고정된 노트 — 핀 아이콘이 제목 앞에 선다',
  age: const Duration(days: 1),
  isPinned: true,
  tags: [tagWork],
);

final Note noteMarkdown = _note(
  id: 'note-markdown',
  displayId: 4,
  content:
      '## 마크다운 제목\n\n**굵게**와 `코드`가 섞인 본문.\n\n- 첫째\n- 둘째\n\n'
      '> 인용문은 왼쪽에 선이 선다.',
  age: const Duration(days: 2),
  tags: [tagIdea],
);

final Note noteWithAttachments = _note(
  id: 'note-media',
  displayId: 5,
  content: '첨부가 붙은 노트',
  age: const Duration(days: 3),
  attachments: [showcaseImage, showcaseFile],
);

final Note noteLink = _note(
  id: 'note-link',
  displayId: 6,
  content: 'https://flutter.dev 링크가 든 노트',
  age: const Duration(days: 4),
  hasLink: true,
);

final Note noteEmpty = _note(
  id: 'note-empty',
  displayId: 7,
  content: '',
  age: const Duration(days: 5),
);

final Note todoOpen = _note(
  id: 'todo-open',
  displayId: 8,
  content: '쇼케이스에 States 페이지 붙이기',
  age: const Duration(hours: 2),
  type: NoteType.todo,
);

final Note todoDone = _note(
  id: 'todo-done',
  displayId: 9,
  content: '토큰 스케일에 3xl 추가',
  age: const Duration(hours: 6),
  type: NoteType.todo,
  completedAgo: const Duration(minutes: 30),
);

final Note replyChild = _note(
  id: 'note-reply',
  displayId: 10,
  content: '위 노트에 달린 답글 — 한 단 들여쓴다',
  age: const Duration(hours: 1),
  parentId: 'note-long',
);

/// 목록 한 판. 깊이·맥락 전용·미아 답글이 다 섞여 있다.
final List<NoteRow> showcaseRows = [
  NoteRow(note: notePinned, depth: 0),
  NoteRow(note: todoOpen, depth: 0),
  NoteRow(note: todoDone, depth: 0),
  NoteRow(note: noteLong, depth: 0),
  NoteRow(note: replyChild, depth: 1),
  NoteRow(note: noteWithAttachments, depth: 0),
  NoteRow(note: noteShort, depth: 0),
  NoteRow(note: noteLink, depth: 0),
];
