// Audit — 토큰을 쓰지 않은 자리 (BRU-172).
//
// 쇼케이스가 예쁜 것만 보여주면 관측 도구가 아니다. MASTER.md 규칙 2는
// "컴포넌트에 raw hex 금지 — 토큰만"인데, 실제로는 지켜지지 않는 자리가 남아 있다.
// 여기 목록은 2026-08-29 기준 실측이고, 대비 숫자는 지금 화면에서 다시 잰 것이다.

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
    severity: 'danger',
    title: 'UserMenu가 다크 단일 모드 시절 색을 그대로 쓴다',
    body:
      '팔레트가 웜 페이퍼 + 라이트/다크 2모드로 바뀌기 전(BRU-72)의 색이 남았다. ' +
      '흰 글자·회색 글자가 하드코딩돼 있어 라이트 모드에서 밝은 표면 위에 흰 글자가 얹힌다. ' +
      '토큰(--text-primary / --text-secondary / --text-on-accent)으로 갈아야 한다.',
    where: 'components/UserMenu.tsx:380, 420, 438, 446, 518, 530 (#fff · #888 · #ccc)',
  },
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
    title: 'index.css에 남은 색 리터럴 3개',
    body:
      '944행은 흐린 배경 위 오버레이 버튼 글자, 3876행은 위험 버튼 위 글자다 — 아래에서 대비를 실측했다. ' +
      '1272행 #000은 9:16 영상 레터박스라 표면색이 아니고, 이건 예외로 두는 편이 맞다.',
    where: 'styles/index.css:944, 1272, 3876',
  },
  {
    severity: 'warning',
    title: '스타일이 3,968줄 단일 파일에 전역 클래스로 들어 있다',
    body:
      '컴포넌트 32개가 모두 index.css 하나를 공유한다. 어떤 규칙이 어떤 컴포넌트의 것인지 ' +
      '이름으로만 알 수 있고, 지울 수 있는 규칙인지 판단할 근거가 없다. ' +
      '컴포넌트를 추출할 때 함께 쪼개는 것이 자연스럽다 — 이 이슈의 범위는 아니다.',
    where: 'styles/index.css',
  },
]

/** 문서에서 옮겨 적지 않고 지금 화면 값으로 다시 재는 짝. */
const MEASURED = [
  { label: '#fff / --danger', fg: '#ffffff', bg: '--danger', note: 'index.css:3876 위험 버튼' },
  { label: '#fff / --cta', fg: '#ffffff', bg: '--cta', note: '주요 행동 버튼에 흰 글자를 쓴다면' },
  { label: '--text-on-accent / #ffffff', fg: '--text-on-accent', bg: '#ffffff', note: 'AuthScreen:99 흰 버튼' },
  { label: '#888 / --bg-elevated', fg: '#888888', bg: '--bg-elevated', note: 'UserMenu:446 이메일 줄' },
  { label: '#ccc / --bg-elevated', fg: '#cccccc', bg: '--bg-elevated', note: 'UserMenu:518 메뉴 항목' },
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

      <Section title="적발" note="2026-08-29 기준 실측. 고치는 것은 이 이슈의 범위가 아니다 — 보이게 하는 것까지가 여기 몫이다.">
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
