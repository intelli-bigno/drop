// Patterns — 여러 컴포넌트가 모여 하나의 뜻을 이루는 자리 (BRU-172).
//
// 노트 행이 이 앱의 중심 패턴이다. 상태가 많고(포커스·호버·핀·잠김·반출·계층)
// 그 조합이 곧 화면 밀도를 정한다.

import { PageHead, Section, Specimen } from '../parts'
import { NoteCard } from '../../components/NoteCard'
import { STYLEGUIDE_ARCHIVED, STYLEGUIDE_NOTES, STYLEGUIDE_TRASHED } from '../fixtures'

const noop = () => {}

/** 노트 행 하나를 카드 배경 위에 얹어 보여준다 — 피드에서의 자리와 같게. */
function Row({
  label,
  index,
  focused = false,
  depth = 0,
  viewMode = 'active' as const,
}: {
  label: string
  index: number
  focused?: boolean
  depth?: number
  viewMode?: 'active' | 'archived' | 'trash'
}) {
  const source =
    viewMode === 'archived'
      ? STYLEGUIDE_ARCHIVED
      : viewMode === 'trash'
        ? STYLEGUIDE_TRASHED
        : STYLEGUIDE_NOTES
  const note = source[Math.min(index, source.length - 1)]

  return (
    <Specimen name={label} flush>
      <NoteCard
        note={note}
        isFocused={focused}
        depth={depth}
        viewMode={viewMode}
        onEscapeFromNormal={noop}
        onReply={noop}
        onPopoverOpenChange={noop}
      />
    </Specimen>
  )
}

export function Patterns() {
  return (
    <>
      <PageHead title="Patterns">
        노트 행은 이 앱에서 가장 자주 보이는 것이고, 밀도를 정하는 것도 이것이다.
        세로 패딩은 <code className="sg-mono">--space-1</code>(4px) — MASTER.md가 적어 둔
        밀도 7/10이 여기서 나온다. 아래는 전부 실물 <code className="sg-mono">NoteCard</code>다.
      </PageHead>

      <Section title="노트 행 — 상태별">
        <Row label="상단 고정 · 우선순위 지정" index={0} />
        <Row label="포커스 (j/k로 이동한 자리)" index={1} focused />
        <Row label="자식 노트 (depth 1)" index={2} depth={1} />
        <Row label="첨부가 있는 노트" index={3} />
        <Row label="Linear로 반출된 노트" index={4} />
        <Row label="링크가 있는 노트" index={6} />
        <Row label="잠긴 노트" index={7} />
        <Row label="빈 노트 — 방금 만든 자리" index={8} />
      </Section>

      <Section
        title="노트 행 — 뷰 모드별"
        note="보관함·휴지통은 액션 세트가 다르다. 같은 카드가 다른 버튼을 단다."
      >
        <Row label="보관함" index={0} viewMode="archived" />
        <Row label="휴지통" index={0} viewMode="trash" />
      </Section>

      <Section
        title="계층"
        note="답글은 노트의 자식이다. 목록에서는 들여쓰기로만 구분하고 별도 화면을 만들지 않는다."
      >
        <Specimen name="부모 + 자식" flush>
          <NoteCard
            note={STYLEGUIDE_NOTES[1]}
            isFocused={false}
            depth={0}
            viewMode="active"
            onEscapeFromNormal={noop}
            onReply={noop}
            onPopoverOpenChange={noop}
          />
          <NoteCard
            note={STYLEGUIDE_NOTES[2]}
            isFocused={false}
            depth={1}
            viewMode="active"
            onEscapeFromNormal={noop}
            onReply={noop}
            onPopoverOpenChange={noop}
          />
        </Specimen>
      </Section>
    </>
  )
}
