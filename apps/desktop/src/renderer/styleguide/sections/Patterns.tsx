// Patterns — 여러 컴포넌트가 모여 하나의 뜻을 이루는 자리 (BRU-172).
//
// 노트 행이 이 앱의 중심 패턴이다. 상태가 많고(포커스·호버·핀·잠김·반출·계층)
// 그 조합이 곧 화면 밀도를 정한다.

import { useState } from 'react'
import { PageHead, Section, Specimen } from '../parts'
import { NoteCard } from '../../components/NoteCard'
import { Icon } from '../../components/Icon'
import { toggleExpandedNote } from '../../lib/note-edit-mode'
import { STYLEGUIDE_ARCHIVED, STYLEGUIDE_NOTES, STYLEGUIDE_TRASHED } from '../fixtures'
import type { Note } from '@drop/shared'

const noop = () => {}

/**
 * 표본이 가리킬 노트를 **조건으로** 찾는다.
 *
 * 전에는 배열 인덱스로 집었는데, 픽스처에 할일 두 건을 끼워 넣자 뒤 인덱스가
 * 통째로 밀려 "빈 노트" 표본이 할일을 보여주고 있었다 (BRU-187). 라벨과 내용이
 * 조용히 어긋나는 종류라 화면만 봐서는 눈치채기 어렵다 — 조건으로 찾으면
 * 픽스처 순서가 바뀌어도 표본이 따라간다.
 */
function pick(source: Note[], match: (note: Note) => boolean): Note {
  const found = source.find(match)
  if (!found) throw new Error('쇼케이스 픽스처에서 해당 상태의 노트를 찾지 못했다')
  return found
}

/** 노트 행 하나를 피드에서의 자리와 같게 얹어 보여준다. */
function Row({
  label,
  note,
  focused = false,
  depth = 0,
  viewMode = 'active' as const,
  expandAll = false,
}: {
  label: string
  note: Note
  focused?: boolean
  depth?: number
  viewMode?: 'active' | 'archived' | 'trash'
  expandAll?: boolean
}) {
  return (
    <Specimen name={label} flush>
      <NoteCard
        note={note}
        isFocused={focused}
        depth={depth}
        viewMode={viewMode}
        expandAll={expandAll}
        onEscapeFromNormal={noop}
        onReply={noop}
        onPopoverOpenChange={noop}
      />
    </Specimen>
  )
}

/** 실제 피드의 묶음 — 이름표 + 둥근 면 + 행 사이 얇은 선 (BRU-213). */
function Group({
  label,
  title,
  notes,
  pinned = false,
}: {
  label: string
  title: string
  notes: Note[]
  pinned?: boolean
}) {
  // 실물과 같은 규칙으로 펼친다 (BRU-213) — 한 번에 하나, 같은 자리를 다시 누르면 접힘.
  const [expandedId, setExpandedId] = useState<string | null>(null)

  return (
    <Specimen name={label} flush>
      <div className="date-group">
        <div className={`date-label ${pinned ? 'is-pinned' : ''}`}>
          {pinned && <Icon name="pin" size={12} />}
          {title}
        </div>
        <div className="note-group">
          {notes.map((note) => (
            <div className="note-row" key={note.id}>
              <NoteCard
                note={note}
                isFocused={false}
                viewMode="active"
                isExpanded={expandedId === note.id}
                onToggleExpand={() =>
                  setExpandedId((current) => toggleExpandedNote(current, note.id))
                }
                onEscapeFromNormal={noop}
                onReply={noop}
                onPopoverOpenChange={noop}
              />
            </div>
          ))}
        </div>
      </div>
    </Specimen>
  )
}

const N = STYLEGUIDE_NOTES

/**
 * 트리 가이드 표본 (BRU-190).
 *
 * 그리는 데 필요한 것은 `depth` 하나뿐이다 — brxce의 IndentationGuides와 같다.
 * 조상 열마다 세로선을 긋고 끝이고, 엘보도 마지막 자식 판정도 없다.
 * 그래서 계층 계산(buildNoteRows)은 손대지 않았다.
 */
const TREE_DEMO = [0, 1, 2, 1].map((depth, index) => ({
  key: `tree-${index}`,
  depth,
  note: N[index % N.length],
}))

export function Patterns() {
  return (
    <>
      <PageHead title="Patterns">
        노트 행은 이 앱에서 가장 자주 보이는 것이고, 밀도를 정하는 것도 이것이다.
        안쪽 여백은 <code className="sg-mono">--space-2 --space-4</code>(8/16px) — 접힌 줄과
        펼친 본문이 <strong>같은 값</strong>을 써야 노트를 펼칠 때 글자가 제자리에 있다
        (BRU-213). 아래는 전부 실물 <code className="sg-mono">NoteCard</code>이고, 실제
        목록에서는 이 행들이 둥근 묶음 면 안에 얇은 선으로 갈려 선다.
      </PageHead>

      <Section
        title="묶음"
        note="행은 혼자 서지 않는다 — 날짜(또는 고정)마다 둥근 면 하나에 담기고 사이는 얇은 선이다. 고정 묶음은 이름표에 핀이 붙는다. 줄을 눌러 보라 — 그 자리에서 펼쳐지고, 다시 누르면 접힌다 (BRU-213)."
      >
        <Group label="날짜 묶음" title="2026년 9월 3일" notes={N.slice(0, 3)} />
        <Group label="고정 묶음" title="고정" notes={N.slice(0, 2)} pinned />
      </Section>

      <Section
        title="노트 행 — 펼친 자리"
        note="「모두 펼쳐보기」와 편집 진입에서 나오는 모습. 아이콘이 본문 첫 줄 옆에 서고, 본문은 접힌 줄의 글자와 같은 x에서 시작한다 — 펼칠 때 글자가 움직이면 안 된다 (BRU-213)."
      >
        <Row label="펼침 — 마크다운 본문" note={pick(N, (n) => n.content.includes('\n'))} expandAll />
        <Row label="펼침 — 한 문단" note={N[0]} expandAll />
      </Section>

      <Section title="노트 행 — 상태별">
        <Row label="상단 고정 · 우선순위 지정" note={pick(N, (n) => n.isPinned)} />
        <Row
          label="포커스 (j/k로 이동한 자리)"
          note={pick(N, (n) => n.parentId === null && !n.isPinned && n.tags.length > 0)}
          focused
        />
        <Row label="자식 노트 (depth 1)" note={pick(N, (n) => n.parentId !== null)} depth={1} />
        <Row label="첨부가 있는 노트" note={pick(N, (n) => n.attachments.length > 0)} />
        <Row label="Linear로 반출된 노트" note={pick(N, (n) => n.linearIssueUrl !== null)} />
        <Row label="링크가 있는 노트" note={pick(N, (n) => n.hasLink)} />
        <Row label="잠긴 노트" note={pick(N, (n) => n.isLocked)} />
        <Row label="빈 노트 — 방금 만든 자리" note={pick(N, (n) => n.content.trim() === '')} />
      </Section>

      <Section
        title="노트 행 — 할일"
        note="할일에는 체크박스, 노트에는 문서 아이콘. 같은 칸을 쓰므로 섞인 목록에서도 왼쪽 가장자리가 한 줄로 맞는다 (BRU-187)."
      >
        <Row
          label="할일 — 미완료"
          note={pick(N, (n) => n.type === 'todo' && n.completedAt === null)}
        />
        <Row
          label="할일 — 완료 (흐려지고 취소선)"
          note={pick(N, (n) => n.type === 'todo' && n.completedAt !== null)}
        />
        <Row
          label="일반 노트 — 문서 아이콘"
          note={pick(N, (n) => n.type === 'note' && n.parentId === null && !n.isPinned)}
        />
      </Section>

      <Section
        title="노트 행 — 뷰 모드별"
        note="보관함·휴지통은 액션 세트가 다르다. 같은 카드가 다른 버튼을 단다."
      >
        <Row label="보관함" note={STYLEGUIDE_ARCHIVED[0]} viewMode="archived" />
        <Row label="휴지통" note={STYLEGUIDE_TRASHED[0]} viewMode="trash" />
      </Section>

      <Section
        title="계층"
        note="답글은 노트의 자식이다. 목록에서는 들여쓰기로만 구분하고 별도 화면을 만들지 않는다."
      >
        <Specimen
          name="3단 중첩"
          desc="조상 열마다 레일이 서고, 형제가 연속하면 한 줄로 이어진다"
          flush
        >
          {/*
            그리려는 모양 (BRU-190) — 들여쓰기 칸마다 세로선이 하나씩 선다:

              a
              │  a1
              │  │  a1a
              │  a2
          */}
          {TREE_DEMO.map((row) => (
            <NoteCard
              key={row.key}
              note={row.note}
              isFocused={false}
              depth={row.depth}
              viewMode="active"
              onEscapeFromNormal={noop}
              onReply={noop}
              onPopoverOpenChange={noop}
            />
          ))}
        </Specimen>
      </Section>
    </>
  )
}
