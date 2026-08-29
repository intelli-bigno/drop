// Layouts — 화면이 놓이는 틀 (BRU-172).
//
// 컴포넌트가 아니라 배치를 본다. 창은 두 종류뿐이다: 본 창과 퀵캡처 창.

import { PageHead, Section, Specimen } from '../parts'
import { NoteFeed } from '../../components/NoteFeed'
import { QuickCapture } from '../../components/QuickCapture'
import { UserMenu } from '../../components/UserMenu'

export function Layouts() {
  return (
    <>
      <PageHead title="Layouts">
        DROP은 화면이 하나다 — 단일 컬럼 피드. 사이드바도 탭도 없고, 분류는 헤더의 필터가
        맡는다. 창은 본 창과 전역 단축키로 뜨는 퀵캡처 창 둘뿐이다.
      </PageHead>

      <Section
        title="앱 셸"
        note={
          <>
            헤더 왼쪽 88px는 macOS 트래픽 라이트 자리로 비워 둔다(<code className="sg-mono">
              .app-header
            </code>). 헤더 전체가 <code className="sg-mono">-webkit-app-region: drag</code>이라
            창을 끌 수 있고, 그 안의 버튼만 <code className="sg-mono">no-drag</code>으로 되돌린다.
          </>
        }
      >
        <Specimen name="app-header + app-content" file="App.tsx" flush>
          <div className="sg-frame sg-frame--feed">
            <div className="app-header">
              <div className="app-header-right">
                <UserMenu onOpenCheatSheet={() => {}} />
              </div>
            </div>
            <div className="sg-frame-body">
              <NoteFeed />
            </div>
          </div>
        </Specimen>
      </Section>

      <Section
        title="퀵캡처 창"
        note="전역 단축키로 뜨는 별도 창. 인증 앞단에서 갈라지는 라우트라 로그인 상태와 무관하게 뜬다."
      >
        <Specimen name="QuickCapture" file="components/QuickCapture.tsx" flush>
          <div className="sg-frame sg-frame--capture">
            <QuickCapture />
          </div>
        </Specimen>
      </Section>
    </>
  )
}
