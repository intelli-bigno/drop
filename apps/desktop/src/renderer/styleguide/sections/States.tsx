// States — 빈 / 로딩 / 오류 (BRU-172).
//
// MASTER.md 규칙 5가 요구하는 세 상태다. 셋 다 실제 피드를 그 상태로 몰아넣어 보여준다 —
// 가짜 마크업을 그리면 "우리 앱의 빈 화면"이 아니라 "빈 화면 그림"이 된다.
//
// 스토어는 전역이라 여기서 바꾼 상태는 다른 섹션에도 보인다. 그래서 섹션을 떠날 때
// 픽스처를 다시 붓는다.

import { useEffect, useState } from 'react'
import { PageHead, Section, Specimen } from '../parts'
import { NoteFeed } from '../../components/NoteFeed'
import { useNotesStore } from '../../stores/notes'
import { useToastStore } from '../../stores/toast'
import { seedStyleguideStores } from '../seed'

type FeedState = '픽스처' | '빈 목록' | '로딩'

export function States() {
  const [state, setState] = useState<FeedState>('빈 목록')
  const showToast = useToastStore((s) => s.showToast)

  useEffect(() => {
    if (state === '빈 목록') {
      useNotesStore.setState({ notes: [], isLoading: false })
    } else if (state === '로딩') {
      useNotesStore.setState({ isLoading: true })
    } else {
      seedStyleguideStores()
    }
  }, [state])

  // 섹션을 떠나면 원래대로 돌려놓는다.
  useEffect(() => () => seedStyleguideStores(), [])

  return (
    <>
      <PageHead title="States">
        빈 상태는 다음 행동을 알려 줘야 하고, 로딩은 레이아웃을 흔들면 안 되며, 오류는
        토스트로 알리고 재시도를 준다 — MASTER.md 규칙 5. 아래는 실제 피드를 그 상태로
        몰아넣은 것이다.
      </PageHead>

      <Section title="피드 상태">
        <Specimen name="전환" desc="아래 프레임이 즉시 바뀐다">
          <div className="sg-row">
            {(['빈 목록', '로딩', '픽스처'] as FeedState[]).map((option) => (
              <button
                key={option}
                className={state === option ? 'sg-btn sg-btn--accent' : 'sg-btn'}
                aria-pressed={state === option}
                onClick={() => setState(option)}
              >
                {option}
              </button>
            ))}
          </div>
        </Specimen>

        <Specimen name={`NoteFeed — ${state}`} file="components/NoteFeed.tsx" flush>
          <div className="sg-frame sg-frame--feed">
            <div className="sg-frame-body">
              <NoteFeed />
            </div>
          </div>
        </Specimen>
      </Section>

      <Section
        title="오류"
        note="오류는 화면을 갈아 끼우지 않는다 — 하던 것을 그대로 두고 토스트로 알린 뒤 재시도를 준다."
      >
        <Specimen name="오류 토스트 + 재시도" file="stores/toast.ts">
          <button
            className="sg-btn"
            onClick={() =>
              showToast({
                message: '노트를 불러오지 못했습니다',
                variant: 'error',
                actionLabel: '다시 시도',
                onAction: () => showToast({ message: '다시 불러왔습니다' }),
              })
            }
          >
            오류 상황 재현
          </button>
        </Specimen>
      </Section>
    </>
  )
}
