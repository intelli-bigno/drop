import { describe, expect, it } from 'vitest'
import {
  createDoubleCtrlDetector,
  DOUBLE_CTRL_DISPLAY,
  describeDoubleCtrlPermissionFallback,
  describeDoubleCtrlStartFailure,
  shouldUseDoubleCtrlCapture,
} from './double-ctrl'

/** 타임라인을 짧게 쓰기 위한 도우미 — (ctrl 여부, down/up, 시각) */
type Step = [isCtrl: boolean, type: 'down' | 'up', timeMs: number]

function fire(steps: Step[]): boolean[] {
  const detector = createDoubleCtrlDetector()
  return steps.map(([isCtrl, type, timeMs]) => detector.handle({ isCtrl, type, timeMs }))
}

describe('createDoubleCtrlDetector', () => {
  it('임계 시간 내 Ctrl 탭 두 번이면 두 번째 누름 순간 발화한다', () => {
    const results = fire([
      [true, 'down', 0],
      [true, 'up', 100],
      [true, 'down', 250],
      [true, 'up', 350],
    ])
    expect(results).toEqual([false, false, true, false])
  })

  it('수식키 keyup이 유실돼도(합성 이벤트 실측 사례) 누름 두 번으로 발화한다', () => {
    const results = fire([
      [true, 'down', 0],
      [true, 'down', 200],
    ])
    expect(results).toEqual([false, true])
  })

  it('누름 사이 간격이 임계를 넘으면 발화하지 않는다', () => {
    const results = fire([
      [true, 'down', 0],
      [true, 'up', 100],
      [true, 'down', 1000],
      [true, 'up', 1100],
    ])
    expect(results.every((fired) => !fired)).toBe(true)
  })

  it('Ctrl을 누른 채 다른 키를 치면(Ctrl+C 등) 후보가 지워진다', () => {
    const results = fire([
      [true, 'down', 0],
      [false, 'down', 50], // Ctrl+C
      [false, 'up', 80],
      [true, 'up', 100],
      [true, 'down', 200], // 새 후보일 뿐
      [true, 'up', 300],
    ])
    expect(results.every((fired) => !fired)).toBe(true)
  })

  it('탭 사이에 다른 키 입력이 끼면 이어지지 않는다', () => {
    const results = fire([
      [true, 'down', 0],
      [true, 'up', 100],
      [false, 'down', 150],
      [false, 'up', 180],
      [true, 'down', 250],
      [true, 'up', 350],
    ])
    expect(results.every((fired) => !fired)).toBe(true)
  })

  it('길게 눌렀다 뗀 것은 탭이 아니다 — 홀드 해제 직후 누름은 새 후보다', () => {
    const results = fire([
      [true, 'down', 0],
      [true, 'up', 600], // 홀드
      [true, 'down', 700], // 홀드 뒤 재누름 — 발화하면 안 된다
      [true, 'up', 800],
    ])
    expect(results.every((fired) => !fired)).toBe(true)
  })

  it('발화 후 상태가 초기화된다 — 세 번째 탭이 홀로 다시 발화하지 않는다', () => {
    const results = fire([
      [true, 'down', 0],
      [true, 'up', 100],
      [true, 'down', 250], // 발화
      [true, 'up', 350],
      [true, 'down', 500], // 새 시퀀스의 첫 탭일 뿐
      [true, 'up', 600],
    ])
    expect(results).toEqual([false, false, true, false, false, false])
  })

  it('연속 탭 네 번이면 두 번째와 네 번째 누름에서 발화한다', () => {
    const results = fire([
      [true, 'down', 0],
      [true, 'up', 80],
      [true, 'down', 200], // 발화 1
      [true, 'up', 280],
      [true, 'down', 400],
      [true, 'up', 480],
      [true, 'down', 600], // 발화 2
      [true, 'up', 680],
    ])
    expect(results.filter(Boolean).length).toBe(2)
    expect(results[2]).toBe(true)
    expect(results[6]).toBe(true)
  })

  it('임계값을 조정할 수 있다', () => {
    const detector = createDoubleCtrlDetector({ maxTapMs: 1000, maxGapMs: 2000 })
    const steps: Step[] = [
      [true, 'down', 0],
      [true, 'up', 800],
      [true, 'down', 2500],
    ]
    const results = steps.map(([isCtrl, type, timeMs]) =>
      detector.handle({ isCtrl, type, timeMs })
    )
    expect(results[2]).toBe(true)
  })
})

describe('shouldUseDoubleCtrlCapture', () => {
  const base = { storedAccelerator: null, isPackaged: true, platform: 'darwin' }

  it('macOS 설치본 + 사용자 지정 조합 없음이면 쓴다', () => {
    expect(shouldUseDoubleCtrlCapture(base)).toBe(true)
  })

  it('사용자가 조합을 직접 골랐으면 그걸 존중한다', () => {
    expect(shouldUseDoubleCtrlCapture({ ...base, storedAccelerator: 'Alt+D' })).toBe(false)
  })

  it('macOS가 아니면 쓰지 않는다', () => {
    expect(shouldUseDoubleCtrlCapture({ ...base, platform: 'win32' })).toBe(false)
  })

  it('dev 실행은 설치본과의 경합을 피해 기본적으로 쓰지 않는다', () => {
    expect(shouldUseDoubleCtrlCapture({ ...base, isPackaged: false })).toBe(false)
  })

  it('dev라도 명시적으로 켜면 쓴다 (실측 검증용)', () => {
    expect(shouldUseDoubleCtrlCapture({ ...base, isPackaged: false, devOptIn: true })).toBe(true)
  })
})

describe('안내 문구', () => {
  it('권한 없음 문구는 손쉬운 사용 설정 경로와 폴백 조합을 담는다', () => {
    const { title, message } = describeDoubleCtrlPermissionFallback('Alt+Space', 'darwin')
    expect(title.length).toBeGreaterThan(0)
    expect(message).toContain('손쉬운 사용')
    expect(message).toContain('⌥Space')
    expect(message).toContain(DOUBLE_CTRL_DISPLAY)
  })

  it('후킹 시작 실패 문구도 폴백 조합을 담는다', () => {
    const { message } = describeDoubleCtrlStartFailure('Alt+Space', 'darwin')
    expect(message).toContain('⌥Space')
  })
})
