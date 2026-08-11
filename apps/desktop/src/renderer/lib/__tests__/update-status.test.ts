import { describe, it, expect } from 'vitest'
import { describeUpdateStatus, type UpdateStatus } from '../update-status'

describe('describeUpdateStatus', () => {
  it('shouldShowNothingBeforeAnyCheck', () => {
    expect(describeUpdateStatus({ kind: 'idle' })).toBeNull()
  })

  it('shouldSayItIsCheckingInUserLanguage', () => {
    // 내부 상태명('checking')이 그대로 노출되면 안 된다
    const text = describeUpdateStatus({ kind: 'checking' })
    expect(text).toBe('업데이트 확인 중…')
    expect(text).not.toContain('checking')
  })

  it('shouldSayItIsUpToDate', () => {
    expect(describeUpdateStatus({ kind: 'up-to-date' })).toBe('최신 버전입니다')
  })

  it('shouldNameTheAvailableVersion', () => {
    expect(describeUpdateStatus({ kind: 'available', version: '0.0.9' })).toBe(
      '새 버전 v0.0.9 내려받는 중…'
    )
  })

  it('shouldTellUserToRestartOnceDownloaded', () => {
    expect(describeUpdateStatus({ kind: 'downloaded', version: '0.0.9' })).toBe(
      'v0.0.9 준비됨 — 재시작하면 설치됩니다'
    )
  })

  it('shouldSurfaceTheErrorReason', () => {
    expect(describeUpdateStatus({ kind: 'error', message: 'network unreachable' })).toBe(
      '확인 실패: network unreachable'
    )
  })

  it('shouldFallBackWhenErrorHasNoMessage', () => {
    expect(describeUpdateStatus({ kind: 'error', message: '' })).toBe('업데이트를 확인하지 못했습니다')
  })

  // 개발 빌드에서는 updater가 동작하지 않는다 — 사용자에게 그 이유를 알려야 한다
  it('shouldExplainWhyCheckingIsUnavailableInDev', () => {
    const status: UpdateStatus = { kind: 'unsupported' }
    expect(describeUpdateStatus(status)).toBe('개발 빌드에서는 업데이트를 확인하지 않습니다')
  })
})
