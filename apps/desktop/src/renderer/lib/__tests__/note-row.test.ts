// 노트 행에 무엇이 남는가 (BRU-187).
//
// 재설계의 최종 결정은 "행에서 덜어낸다"였다 (2026-08-30 bruce).
// 프로젝트·태그·우선순위·카운트·핀·잠금을 전부 뺐고, 남은 것은
// 상태칸(할일 체크박스) · 본문 · Linear 반출 배지뿐이다.
//
// 뺀 정보가 사라지는 것은 아니다 — 미리보기 패널(Space)이 받는다.
// 핀은 PINNED 그룹 헤더가, 잠금은 본문 자리의 '잠긴 노트' placeholder가 대신한다.

import { describe, expect, it } from 'vitest'
import { resolveRowAdornments } from '../note-row'
import type { RowAdornmentInput } from '../note-row'

const base: RowAdornmentInput = {
  viewMode: 'active',
  isTodo: false,
  isExported: false,
}

const at = (over: Partial<RowAdornmentInput> = {}) => resolveRowAdornments({ ...base, ...over })

describe('상태칸', () => {
  // 노트와 할일이 섞인 목록에서 본문 x가 한 줄로 맞아야 한다.
  // 자리를 비워 두지 않으면 할일만 들여쓰기된 것처럼 보인다.
  it('할일이 아니어도 자리는 예약한다', () => {
    expect(at({ isTodo: false }).reservesStatusSlot).toBe(true)
    expect(at({ isTodo: true }).reservesStatusSlot).toBe(true)
  })

  it('할일에만 체크박스를 그린다', () => {
    expect(at({ isTodo: true }).showsCheckbox).toBe(true)
    expect(at({ isTodo: false }).showsCheckbox).toBe(false)
  })

  // 상태칸이 빈 채로 남으면 목록 왼쪽이 이가 빠진 것처럼 보인다.
  // brxce도 모든 행에 타입 아이콘을 둔다 — 노트형에는 파일 아이콘이다.
  it('할일이 아니면 노트 아이콘을 그린다', () => {
    expect(at({ isTodo: false }).showsNoteIcon).toBe(true)
    expect(at({ isTodo: true }).showsNoteIcon).toBe(false)
  })

  // 체크박스와 노트 아이콘은 같은 칸을 쓰므로 동시에 나올 수 없다.
  it('둘이 동시에 나오지 않는다', () => {
    for (const isTodo of [true, false]) {
      for (const viewMode of ['active', 'archived', 'trash'] as const) {
        const r = at({ isTodo, viewMode })
        expect(r.showsCheckbox && r.showsNoteIcon).toBe(false)
      }
    }
  })

  // 휴지통·보관함의 할일은 체크박스를 못 쓰지만 칸은 비지 않아야 한다.
  it('활성 뷰가 아닌 할일에는 노트 아이콘이 대신 들어간다', () => {
    const r = at({ isTodo: true, viewMode: 'archived' })
    expect(r.showsCheckbox).toBe(false)
    expect(r.showsNoteIcon).toBe(true)
  })

  // 휴지통·보관함에서는 완료를 토글할 수 없다.
  it('활성 뷰가 아니면 체크박스를 그리지 않는다', () => {
    expect(at({ isTodo: true, viewMode: 'trash' }).showsCheckbox).toBe(false)
    expect(at({ isTodo: true, viewMode: 'archived' }).showsCheckbox).toBe(false)
  })
})

describe('본문 뒤', () => {
  it('평소에는 아무것도 붙지 않는다', () => {
    expect(at().trailing).toEqual([])
  })

  // 기본 목록에서는 반출된 노트가 빠져 있어 '반출된 노트 보기'를 켠 목록에서 주로 보인다.
  // 그 목록에서는 어느 이슈로 나갔는지가 곧 그 줄의 존재 이유다.
  it('Linear로 반출된 노트에는 배지가 붙는다', () => {
    expect(at({ isExported: true }).trailing).toEqual(['export'])
  })
})

describe('행에서 덜어낸 것 (2026-08-30 결정)', () => {
  // 아래는 전부 "행에 그리지 않는다"를 고정하는 테스트다.
  // 되살리려면 결정을 다시 하고 이 테스트부터 고쳐야 한다.
  it('프로젝트·태그·우선순위·카운트·핀·잠금은 행이 받지 않는다', () => {
    const keys = Object.keys(at())
    expect(keys).not.toContain('leading')
    // 입력 자체를 받지 않으므로 실수로 그릴 수도 없다
    const inputKeys = Object.keys(base)
    for (const gone of [
      'priority',
      'isPinned',
      'isLocked',
      'hasProject',
      'commentCount',
      'attachmentCount',
      'linkCount',
      'tagCount',
    ]) {
      expect(inputKeys, `${gone}이 아직 입력에 남아 있다`).not.toContain(gone)
    }
  })
})

describe('오른쪽 예약 열', () => {
  // BRU-57이 두었던 206px 예약을 없앤다. 액션은 hover에 떠 있는 툴바로 뜨고
  // 자리를 잡지 않으므로 본문이 그 폭을 되찾는다.
  it('어떤 뷰에서도 예약 폭이 없다', () => {
    expect(at().reservedTrailingWidth).toBe(0)
    expect(at({ viewMode: 'archived' }).reservedTrailingWidth).toBe(0)
    expect(at({ viewMode: 'trash' }).reservedTrailingWidth).toBe(0)
  })
})
