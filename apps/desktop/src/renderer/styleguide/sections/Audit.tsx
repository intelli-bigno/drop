// Audit — 토큰을 쓰지 않은 자리 (BRU-172).
//
// 쇼케이스가 예쁜 것만 보여주면 관측 도구가 아니다. MASTER.md 규칙 2는
// "컴포넌트에 raw hex 금지 — 토큰만"인데, 실제로는 지켜지지 않는 자리가 남아 있다.
// 여기 목록은 2026-09-03 기준 실측이고, 대비 숫자는 지금 화면에서 다시 잰 것이다.

import { PageHead, Section, Specimen } from '../parts'
import { contrastRatio, wcagVerdict } from '../contrast'

interface Finding {
  title: string
  body: string
  where: string
  severity: 'danger' | 'warning'
}

const FINDINGS: Finding[] = [
  {
    severity: 'warning',
    title: 'Google 로그인 버튼이 두 모드 모두 흰 배경이다',
    body:
      'Google 브랜드 가이드를 따른 것이라면 정당한 예외지만, 지금은 그 판단이 코드에 적혀 있지 않다. ' +
      '의도라면 주석으로 못 박고, 아니라면 표면 토큰으로 옮긴다. ' +
      '로고 4색(#4285F4 · #34A853 · #FBBC05 · #EA4335)은 남의 브랜드 색이라 예외가 맞다.',
    where: 'components/AuthScreen.tsx:99, 107',
  },
  {
    severity: 'warning',
    title: '스타일이 4,300줄 단일 파일에 전역 클래스로 들어 있다',
    body:
      '컴포넌트 34개가 모두 index.css 하나를 공유한다. 어떤 규칙이 어떤 컴포넌트의 것인지 ' +
      '이름으로만 알 수 있고, 지울 수 있는 규칙인지 판단할 근거가 없다. ' +
      'BRU-213에서 죽은 규칙 셋과 설명만 남은 주석을 걷었지만 구조는 그대로다 — ' +
      '컴포넌트를 추출할 때 함께 쪼개는 것이 자연스럽다.',
    where: 'styles/index.css',
  },
]

/** 해소된 적발. 지운 것이 아니라 **해소로 남긴다** — 무엇이 왜 없어졌는지가 기록이다. */
const RESOLVED: Finding[] = [
  {
    severity: 'warning',
    title: 'index.css의 색 리터럴 — 40곳 → 0곳 (BRU-213에서 해소)',
    body:
      '개편 전에는 토큰을 안 쓴 생값이 40곳이었고, 그중 셋은 팔레트가 앰버로 바뀌기 전 잔재였다 ' +
      '(파란 드래그 배경 · 붉은 hover 둘 · 핀의 생 앰버). 막(overlay-*) · 위험 면(danger-solid) · ' +
      '막 위 글자(text-on-overlay) 토큰을 새로 세워 전부 옮겼다. 9:16 레터박스의 #000도 ' +
      'overlay-strong으로 갔다 — 예외로 둘 필요가 없었다.',
    where: 'styles/index.css — 실측 0건 (2026-09-03)',
  },
  {
    severity: 'danger',
    title: '다크에서 danger 면 위 흰 글자가 3.76:1이었다 (BRU-213에서 해소)',
    body:
      '아래 표에 그 짝이 없어서 오래 안 보였다. --danger를 어둡게 하면 다크에서 danger를 ' +
      '글자색으로 쓰는 자리가 함께 무너지므로, 채운 면을 --danger-solid로 갈랐다. ' +
      '지금은 라이트 4.95:1 · 다크 6.47:1이다 — Foundations의 대비 표에서 확인한다.',
    where: 'design-system/drop/tokens.json — color.danger-solid',
  },
]

/** 문서에서 옮겨 적지 않고 지금 화면 값으로 다시 재는 짝. */
const MEASURED = [
  { label: '#fff / --danger (옛 방식)', fg: '#ffffff', bg: '--danger', note: 'BRU-213 전. 다크에서 3.76:1로 떨어졌다' },
  { label: '#fff / --cta', fg: '#ffffff', bg: '--cta', note: '주요 행동 버튼에 흰 글자를 쓴다면' },
  { label: '--text-on-accent / #ffffff', fg: '--text-on-accent', bg: '#ffffff', note: 'AuthScreen:99 흰 버튼' },
  {
    label: '--text-on-accent / --accent',
    fg: '--text-on-accent',
    bg: '--accent',
    note: 'UserMenu 아바타 플레이스홀더 (BRU-176로 토큰 교체됨)',
  },
]

function read(token: string): string {
  if (!token.startsWith('--')) return token
  return getComputedStyle(document.documentElement).getPropertyValue(token).trim()
}

export function Audit() {
  return (
    <>
      <PageHead title="Audit">
        MASTER.md 규칙 2는 “컴포넌트에 raw hex 금지 — 토큰만”이다. 지켜지지 않은 자리를 적어 둔다.
        아래 대비 숫자는 지금 이 화면의 토큰 값으로 다시 잰 것이라, 테마를 바꾸면 함께 바뀐다.
      </PageHead>

      <Section title="적발" note="2026-09-03 기준 실측. 남은 둘은 이번 개편의 범위가 아니었다 — 보이게 하는 것까지가 여기 몫이다.">
        {FINDINGS.map((finding) => (
          <div
            key={finding.title}
            className={finding.severity === 'danger' ? 'sg-finding sg-finding--danger' : 'sg-finding'}
          >
            <div className="sg-finding-title">{finding.title}</div>
            <p className="sg-finding-body">{finding.body}</p>
            <div className="sg-finding-where">{finding.where}</div>
          </div>
        ))}
      </Section>

      <Section
        title="해소"
        note="지운 자리가 아니라 해소된 자리로 남긴다 — 무엇이 왜 없어졌는지가 다음 사람에게 필요한 기록이다."
      >
        {RESOLVED.map((finding) => (
          <div key={finding.title} className="sg-finding">
            <div className="sg-finding-title">{finding.title}</div>
            <p className="sg-finding-body">{finding.body}</p>
            <div className="sg-finding-where">{finding.where}</div>
          </div>
        ))}
      </Section>

      <Section
        title="하드코딩된 색의 실제 대비"
        note="지금 테마 기준. 라이트·다크를 오가며 보면 어느 모드에서 깨지는지가 드러난다."
      >
        <Specimen name="측정" file="styleguide/contrast.ts">
          <table className="sg-table">
            <thead>
              <tr>
                <th>짝</th>
                <th>미리보기</th>
                <th>대비</th>
                <th>판정</th>
                <th>어디</th>
              </tr>
            </thead>
            <tbody>
              {MEASURED.map((pair) => {
                const fg = read(pair.fg)
                const bg = read(pair.bg)
                const ratio = contrastRatio(fg, bg)
                const verdict = wcagVerdict(ratio)

                return (
                  <tr key={pair.label}>
                    <td className="sg-mono">{pair.label}</td>
                    <td>
                      <span className="sg-pair-preview" style={{ color: fg, background: bg }}>
                        가나 Ag
                      </span>
                    </td>
                    <td>{ratio ? `${ratio.toFixed(2)}:1` : '잴 수 없음'}</td>
                    <td>
                      <span
                        className={
                          verdict.passes
                            ? 'sg-verdict sg-verdict--pass'
                            : 'sg-verdict sg-verdict--fail'
                        }
                      >
                        {verdict.level}
                      </span>
                    </td>
                    <td style={{ color: 'var(--text-tertiary)' }}>{pair.note}</td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </Specimen>
      </Section>
    </>
  )
}
