import { useEffect, useRef } from 'react'
import {
  groupedCatalog,
  formatKeyForDisplay,
  keysForEntry,
  CHEAT_SHEET_NOTES,
} from '../shortcuts/catalog'

interface Props {
  onClose: () => void
}

/**
 * ⌘/ 로 여는 단축키 치트시트.
 * 목록은 shortcuts/catalog.ts가 shortcuts/keys.ts에서 파생시킨 것이라
 * 여기에는 키를 적지 않는다 — 단축키를 추가하면 자동으로 나타난다.
 * ConfirmDialog와 같은 backdrop/dialog 패턴.
 */
export function ShortcutCheatSheet({ onClose }: Props) {
  const closeRef = useRef<HTMLButtonElement>(null)
  const groups = groupedCatalog()

  useEffect(() => {
    closeRef.current?.focus()
  }, [])

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Escape') {
      e.stopPropagation()
      onClose()
    }
  }

  return (
    <div
      className="cheatsheet-backdrop"
      onClick={onClose}
      onKeyDown={handleKeyDown}
      role="presentation"
    >
      <div
        className="cheatsheet"
        onClick={(e) => e.stopPropagation()}
        role="dialog"
        aria-modal="true"
        aria-label="단축키"
      >
        <div className="cheatsheet-header">
          <h3 className="cheatsheet-title">단축키</h3>
          <button
            ref={closeRef}
            type="button"
            className="cheatsheet-close"
            onClick={onClose}
            aria-label="닫기"
          >
            Esc
          </button>
        </div>

        <div className="cheatsheet-groups">
          {groups.map((group) => (
            <section className="cheatsheet-group" key={group.group}>
              <h4 className="cheatsheet-group-title">{group.group}</h4>
              <ul className="cheatsheet-list">
                {group.entries.map((entry) => (
                  <li className="cheatsheet-row" key={`${entry.group}-${entry.keyId}-${entry.modifier ?? ''}`}>
                    <span className="cheatsheet-label">{entry.label}</span>
                    <span className="cheatsheet-keys">
                      {(entry.modifier === 'primary' || entry.modifier === 'primary-shift') && (
                        <kbd>⌘</kbd>
                      )}
                      {(entry.modifier === 'shift' || entry.modifier === 'primary-shift') && (
                        <kbd>⇧</kbd>
                      )}
                      {keysForEntry(entry).map((k, i) => (
                        <span className="cheatsheet-key-alt" key={k}>
                          {i > 0 && <span className="cheatsheet-or">/</span>}
                          <kbd>{formatKeyForDisplay(k)}</kbd>
                        </span>
                      ))}
                    </span>
                  </li>
                ))}
              </ul>
            </section>
          ))}
        </div>

        <div className="cheatsheet-footnotes">
          {CHEAT_SHEET_NOTES.map((note) => (
            <p className="cheatsheet-footnote" key={note}>
              {note}
            </p>
          ))}
        </div>
      </div>
    </div>
  )
}
