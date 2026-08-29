// 쇼케이스가 자기 자신을 그리는 데 쓰는 조각들 (BRU-172).
// 앱 컴포넌트가 아니다 — 여기 있는 것은 진열대이고, 진열되는 물건은 components/에 있다.

import type { ReactNode } from 'react'

export function PageHead({ title, children }: { title: string; children?: ReactNode }) {
  return (
    <header className="sg-page-head">
      <h1 className="sg-page-title">{title}</h1>
      {children ? <p className="sg-page-lede">{children}</p> : null}
    </header>
  )
}

export function Section({
  id,
  title,
  note,
  children,
}: {
  id?: string
  title: string
  note?: ReactNode
  children: ReactNode
}) {
  return (
    <section className="sg-section" id={id}>
      <h2 className="sg-section-title">{title}</h2>
      {note ? <p className="sg-note">{note}</p> : null}
      {children}
    </section>
  )
}

/**
 * 표본 한 칸. `file`은 진열된 물건이 실제로 사는 곳이다 —
 * 쇼케이스에서 뭔가를 보고 코드로 가려면 그 경로가 있어야 한다.
 */
export function Specimen({
  name,
  desc,
  file,
  flush,
  children,
}: {
  name: string
  desc?: string
  file?: string
  flush?: boolean
  children: ReactNode
}) {
  return (
    <article className="sg-specimen">
      <div className="sg-specimen-head">
        <span className="sg-specimen-name">{name}</span>
        {desc ? <span className="sg-specimen-desc">{desc}</span> : null}
        {file ? <span className="sg-specimen-file">{file}</span> : null}
      </div>
      <div className={flush ? 'sg-specimen-body sg-specimen-body--flush' : 'sg-specimen-body'}>
        {children}
      </div>
    </article>
  )
}
