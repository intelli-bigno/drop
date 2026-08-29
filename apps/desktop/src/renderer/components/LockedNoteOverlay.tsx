import { Icon } from './Icon'

interface Props {
  onTemporaryUnlock: () => void
  onPermanentUnlock: () => void
}

export function LockedNoteOverlay({ onTemporaryUnlock, onPermanentUnlock }: Props) {
  return (
    <div className="locked-note-overlay">
      <div className="locked-note-icon">
        <Icon name="lock" size={24} />
      </div>
      <p className="locked-note-text">잠긴 노트</p>
      <div className="locked-note-actions">
        <button className="locked-note-btn primary" onClick={onTemporaryUnlock}>
          이 세션만 보기
        </button>
        <button className="locked-note-btn secondary" onClick={onPermanentUnlock}>
          잠금 완전 해제
        </button>
      </div>
    </div>
  )
}
