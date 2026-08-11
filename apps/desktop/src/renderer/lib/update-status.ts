// 업데이트 상태 → 사용자 언어 문구.
// 내부 상태명을 그대로 노출하지 않는다 (BRU-31).

export type UpdateStatus =
  | { kind: 'idle' }
  | { kind: 'checking' }
  | { kind: 'up-to-date' }
  | { kind: 'available'; version: string }
  | { kind: 'downloaded'; version: string }
  | { kind: 'error'; message: string }
  /** 개발 빌드 — main 프로세스가 업데이트 확인을 건너뛴다 */
  | { kind: 'unsupported' }

export function describeUpdateStatus(status: UpdateStatus): string | null {
  switch (status.kind) {
    case 'idle':
      return null
    case 'checking':
      return '업데이트 확인 중…'
    case 'up-to-date':
      return '최신 버전입니다'
    case 'available':
      return `새 버전 v${status.version} 내려받는 중…`
    case 'downloaded':
      return `v${status.version} 준비됨 — 재시작하면 설치됩니다`
    case 'error':
      return status.message ? `확인 실패: ${status.message}` : '업데이트를 확인하지 못했습니다'
    case 'unsupported':
      return '개발 빌드에서는 업데이트를 확인하지 않습니다'
  }
}
