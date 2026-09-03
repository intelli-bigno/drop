import { useEffect, useRef, useState } from 'react'
import {
  groupedCatalog,
  formatKeyForDisplay,
  keysForEntry,
  CHEAT_SHEET_NOTES,
} from '../shortcuts/catalog'
import { formatAccelerator } from '../../shared/shortcuts'

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
  // 앱 밖에서 도는 유일한 단축키 (BRU-84). 사용자가 바꿀 수 있어서 표에 못 적고,
  // 그래서 지금까지 「모든 단축키」 목록에 빠져 있었다 (BRU-213).
  const [globalShortcut, setGlobalShortcut] =
    useState<{ accelerator: string; registered: boolean } | null>(null)

  useEffect(() => {
    closeRef.current?.focus()
  }, [])

  useEffect(() => {
    void window.api.settings
      .getQuickCaptureShortcut()
      // 등록에 실패했으면 accelerator가 null이다. 그때도 **적어 준다** —
      // 목록에서 통째로 사라지면 "그런 단축키가 없다"로 읽힌다.
      .then((state) =>
        setGlobalShortcut({
          accelerator: state.accelerator ?? state.fallback,
          registered: state.registered,
        })
      )
      .catch(() => setGlobalShortcut(null))
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

        {/* 앱이 떠 있지 않아도 듣는 단축키. 나머지와 층이 달라 따로 세운다. */}
        {globalShortcut && (
          <section
            className={`cheatsheet-global ${globalShortcut.registered ? '' : 'is-inactive'}`}
          >
            <div className="cheatsheet-row">
              <span className="cheatsheet-label">
                어디서든 퀵캡처 열기
                <span className="cheatsheet-sub">
                  {globalShortcut.registered
                    ? '앱이 뒤에 있어도 듣는다 · 사용자 메뉴 「전역 단축키」에서 바꾼다'
                    : '지금은 등록되지 않았다 — 다른 앱이 같은 조합을 쓰고 있을 수 있다'}
                </span>
              </span>
              <span className="cheatsheet-keys">
                <kbd>{formatAccelerator(globalShortcut.accelerator, window.api.platform)}</kbd>
              </span>
            </div>
          </section>
        )}

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
