import { useMemo, Fragment } from 'react'
import { parseNoteBlocks, parseInlineSpans, type InlineSpan } from '../lib/note-viewer'

/**
 * 포커스된 노트를 **읽기 전용**으로 펼쳐 그린다 (BRU-59).
 *
 * 이 컴포넌트에는 입력 경로가 없다 — `contenteditable`도, Lexical도, 저장
 * 호출도 없다. 펼치기만 해도 원문이 덮어써졌던 BRU-66은 펼침과 편집이 같은
 * 상태였기 때문에 났다. 여기서는 구조적으로 그 일이 일어날 수 없다.
 */
export function NoteViewer({ content }: { content: string }) {
  const blocks = useMemo(() => parseNoteBlocks(content), [content])

  if (blocks.length === 0) {
    return (
      <div className="note-viewer">
        <p className="note-viewer-empty">빈 노트</p>
      </div>
    )
  }

  return (
    // 읽기 전용이라는 사실을 보조기술에도 알린다
    <div className="note-viewer" role="article" aria-readonly="true">
      {blocks.map((block, index) => {
        switch (block.type) {
          case 'heading': {
            const Tag = `h${Math.min(block.level, 6)}` as 'h1'
            return (
              <Tag key={index} className="note-viewer-heading">
                <Inline text={block.text} />
              </Tag>
            )
          }
          case 'list':
            return block.ordered ? (
              <ol key={index} className="note-viewer-list">
                {block.items.map((item, itemIndex) => (
                  <li key={itemIndex}>
                    <Inline text={item} />
                  </li>
                ))}
              </ol>
            ) : (
              <ul key={index} className="note-viewer-list">
                {block.items.map((item, itemIndex) => (
                  <li key={itemIndex}>
                    <Inline text={item} />
                  </li>
                ))}
              </ul>
            )
          case 'tasks':
            return (
              <ul key={index} className="note-viewer-list note-viewer-tasks">
                {block.items.map((item, itemIndex) => (
                  <li key={itemIndex} className={item.checked ? 'checked' : undefined}>
                    {/* 표시일 뿐 조작할 수 없다 — 체크는 편집 모드에서 한다 */}
                    <span className="note-viewer-checkbox" aria-hidden="true">
                      {item.checked ? '☑' : '☐'}
                    </span>
                    <Inline text={item.text} />
                  </li>
                ))}
              </ul>
            )
          case 'quote':
            return (
              <blockquote key={index} className="note-viewer-quote">
                <Inline text={block.text} />
              </blockquote>
            )
          case 'code':
            return (
              <pre key={index} className="note-viewer-code">
                <code>{block.text}</code>
              </pre>
            )
          case 'divider':
            return <hr key={index} className="note-viewer-divider" />
          case 'paragraph':
          default:
            return (
              <p key={index} className="note-viewer-paragraph">
                <Inline text={block.text} />
              </p>
            )
        }
      })}
    </div>
  )
}

function Inline({ text }: { text: string }) {
  const spans = useMemo(() => parseInlineSpans(text), [text])
  return (
    <>
      {spans.map((span, index) => (
        <Fragment key={index}>{renderSpan(span)}</Fragment>
      ))}
    </>
  )
}

function renderSpan(span: InlineSpan) {
  switch (span.type) {
    case 'strong':
      return <strong>{span.text}</strong>
    case 'code':
      return <code className="note-viewer-inline-code">{span.text}</code>
    case 'link':
      return (
        <button
          className="note-viewer-link"
          // 카드 클릭(포커스 이동)까지 번지지 않게 막는다
          onClick={(e) => {
            e.stopPropagation()
            window.api.openExternal(span.href)
          }}
          title={span.href}
        >
          {span.text}
        </button>
      )
    case 'text':
    default:
      return span.text
  }
}
