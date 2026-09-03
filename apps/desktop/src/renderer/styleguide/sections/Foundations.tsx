// Foundations — 토큰 (BRU-172).
//
// 값을 코드에 적지 않는다. 화면에 실제로 적용된 값을 getComputedStyle로 읽어 보여준다.
// 그래서 tokens.json을 고치고 `make tokens`를 돌리면 이 화면이 바로 따라온다.

import { useEffect, useState } from 'react'
import { PageHead, Section, Specimen } from '../parts'
import { contrastRatio, wcagVerdict } from '../contrast'
import {
  COLOR_GROUPS,
  CONTRAST_PAIRS,
  FONT_TOKENS,
  RADIUS_TOKENS,
  SHADOW_TOKENS,
  SPACE_TOKENS,
  TEXT_TOKENS,
  TRANSITION_TOKENS,
  TYPE_ROLES,
} from '../tokens-catalog'

/** 지금 문서에 적용된 토큰 값을 읽는다. 토큰이 아니면(직접 적은 색) 그대로 돌려준다. */
function useTokenReader(): (token: string) => string {
  const [, force] = useState(0)

  // 테마가 바뀌면 값도 바뀐다 — data-theme 변화를 보고 다시 읽는다.
  useEffect(() => {
    const observer = new MutationObserver(() => force((n) => n + 1))
    observer.observe(document.documentElement, { attributes: true, attributeFilter: ['data-theme'] })

    const media = window.matchMedia('(prefers-color-scheme: dark)')
    const onChange = () => force((n) => n + 1)
    media.addEventListener('change', onChange)

    return () => {
      observer.disconnect()
      media.removeEventListener('change', onChange)
    }
  }, [])

  return (token: string) => {
    if (!token.startsWith('--')) return token
    return getComputedStyle(document.documentElement).getPropertyValue(token).trim()
  }
}

export function Foundations() {
  const read = useTokenReader()

  return (
    <>
      <PageHead title="Foundations">
        색·간격·타이포의 정본은 <code className="sg-mono">design-system/drop/tokens.json</code> 하나이고,
        같은 값이 iOS·Android·Flutter로도 나간다. 아래 값은 이 화면에 실제로 적용된 것을 읽어
        온 것이라 <code className="sg-mono">make tokens</code>를 돌리면 여기도 따라 바뀐다.
      </PageHead>

      {COLOR_GROUPS.map((group) => (
        <Section key={group.title} title={`색 — ${group.title}`} note={group.note}>
          <div className="sg-grid">
            {group.tokens.map((token) => (
              <div className="sg-swatch" key={token}>
                <div className="sg-swatch-chip">
                  <div className="sg-swatch-fill" style={{ background: `var(${token})` }} />
                </div>
                <div className="sg-swatch-meta">
                  <div className="sg-swatch-name">{token}</div>
                  <div className="sg-swatch-value">{read(token) || '—'}</div>
                </div>
              </div>
            ))}
          </div>
        </Section>
      ))}

      <Section
        title="대비"
        note={
          <>
            본문 4.5:1, 큰 글자 3:1 기준. 여기 숫자는 문서에서 옮겨 적은 것이 아니라 지금 화면의
            토큰 값으로 다시 잰 것이다 — 마지막 줄이 MASTER.md가 “쓰지 말라”고 적어 둔 조합이고,
            실제로 떨어지는 것을 여기서 확인할 수 있다.
          </>
        }
      >
        <Specimen name="토큰 짝별 대비비" file="styleguide/contrast.ts">
          <table className="sg-table">
            <thead>
              <tr>
                <th>짝</th>
                <th>미리보기</th>
                <th>대비</th>
                <th>기준</th>
                <th>판정</th>
              </tr>
            </thead>
            <tbody>
              {CONTRAST_PAIRS.map((pair) => {
                const fg = read(pair.foreground)
                const bg = read(pair.background)
                const ratio = contrastRatio(fg, bg)
                const verdict = wcagVerdict(ratio, { largeText: pair.large })

                return (
                  <tr key={pair.label}>
                    <td>{pair.label}</td>
                    <td>
                      <span className="sg-pair-preview" style={{ color: fg, background: bg }}>
                        가나 Ag
                      </span>
                    </td>
                    <td>{ratio ? `${ratio.toFixed(2)}:1` : '잴 수 없음'}</td>
                    <td className="sg-mono">{pair.large ? '3:1' : '4.5:1'}</td>
                    <td>
                      <span
                        className={
                          verdict.passes ? 'sg-verdict sg-verdict--pass' : 'sg-verdict sg-verdict--fail'
                        }
                      >
                        {verdict.level}
                      </span>
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </Specimen>
      </Section>

      <Section title="간격" note="4px 베이스. 카드 내부 밀도는 --space-1이 정한다.">
        <Specimen name="--space-1 … --space-8">
          {SPACE_TOKENS.map((token) => (
            <div className="sg-bar" key={token}>
              <span className="sg-bar-label">{token}</span>
              <span className="sg-bar-fill" style={{ width: `var(${token})` }} />
              <span className="sg-bar-value">{read(token)}</span>
            </div>
          ))}
        </Specimen>
      </Section>

      <Section title="라디우스">
        <div className="sg-grid sg-grid--tight">
          {RADIUS_TOKENS.map((token) => (
            <div className="sg-radius-box" key={token} style={{ borderRadius: `var(${token})` }}>
              {read(token)}
            </div>
          ))}
        </div>
      </Section>

      <Section
        title="타이포"
        note={
          // `note`는 ReactNode다 — 마크다운을 파싱하지 않는다. 문자열에 `**`와
          // 백틱을 적어 두었더니 화면에 그 기호가 그대로 찍혀 있었다 (BRU-213).
          <>
            크기는 스케일이 정하고 <strong>뜻은 역할이 정한다</strong> (BRU-213). 화면은{' '}
            <code className="sg-mono">font-size: 15px</code>가 아니라{' '}
            <code className="sg-mono">font: var(--type-reading)</code>을 쓴다 — 그래야 같은 뜻의
            글자가 자리마다 달라지지 않는다. 12px 미만은 본문에 쓰지 않는다.
          </>
        }
      >
        <Specimen name="스케일">
          {TEXT_TOKENS.map((token) => (
            <div className="sg-type-sample" key={token}>
              <span className="sg-bar-label">{token}</span>
              <span style={{ fontSize: `var(${token})` }}>
                오늘 붙잡은 생각을 한 줄로 남긴다
              </span>
              <span className="sg-bar-value">{read(token)}</span>
            </div>
          ))}
        </Specimen>

        <Specimen
          name="역할"
          file="styles/typography.css"
        >
          {TYPE_ROLES.map((role) => (
            <div className="sg-type-sample" key={role.token}>
              <span className="sg-bar-label">{role.token.replace('--type-', '')}</span>
              <span
                style={{
                  font: `var(${role.token})`,
                  letterSpacing: `var(${role.token}-tracking)`,
                }}
              >
                오늘 붙잡은 생각을 한 줄로
              </span>
              <span className="sg-bar-value">{role.use}</span>
            </div>
          ))}
        </Specimen>

        <Specimen name="폰트">
          {FONT_TOKENS.map((token) => (
            <div className="sg-type-sample" key={token}>
              <span className="sg-bar-label">{token}</span>
              <span style={{ fontFamily: `var(${token})`, fontSize: 'var(--text-base)' }}>
                DROP 0123 — quick capture
              </span>
            </div>
          ))}
        </Specimen>
      </Section>

      <Section title="그림자" note="띄우는 정도로만 쓴다 — 카드 자체는 보더로 나눈다.">
        <div className="sg-grid">
          {SHADOW_TOKENS.map((token) => (
            <div className="sg-shadow-box" key={token} style={{ boxShadow: `var(${token})` }}>
              {token}
            </div>
          ))}
        </div>
      </Section>

      <Section
        title="전환"
        note="hover는 normal(150ms). prefers-reduced-motion을 켠 환경에서는 앱이 전환을 끈다."
      >
        <Specimen name="--transition-*">
          {TRANSITION_TOKENS.map((token) => (
            <div className="sg-bar" key={token}>
              <span className="sg-bar-label">{token}</span>
              <span className="sg-bar-value">{read(token)}</span>
            </div>
          ))}
        </Specimen>
      </Section>
    </>
  )
}
