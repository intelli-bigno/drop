import { describe, expect, it } from 'vitest'
import { USER_DATA_DIR_SEGMENTS, resolveUserDataDir } from './user-data'

const APP_DATA = '/Users/x/Library/Application Support'

describe('resolveUserDataDir', () => {
  it('설치본이 실제로 쓰는 경로를 그대로 가리킨다 — 실행 중인 v1.0.31에서 실측한 값', () => {
    // 표시 이름이 무엇이든 기존 세션·설정이 살아 있어야 한다.
    // 이 경로는 추측이 아니라 실행 중 프로세스의 --user-data-dir 인자에서 읽었다.
    expect(USER_DATA_DIR_SEGMENTS).toEqual(['@drop', 'desktop'])
    expect(resolveUserDataDir(APP_DATA, true)).toBe(`${APP_DATA}/@drop/desktop`)
  })

  it('표시 이름을 따라 새 디렉터리를 만들지 않는다', () => {
    // 표시 이름으로 만든 경로('DROP' 등)는 빈 디렉터리다. 여기로 가면 전원 로그아웃이다.
    const resolved = resolveUserDataDir(APP_DATA, true)
    expect(resolved.endsWith('/DROP')).toBe(false)
  })

  it('dev 실행은 설치본과 프로필을 공유하지 않는다 — 기존 dev 경로와 같은 이름', () => {
    expect(resolveUserDataDir(APP_DATA, false)).toBe(`${APP_DATA}/@drop/desktop-dev`)
  })

  it('macOS 밖에서도 같은 규칙을 쓴다', () => {
    expect(resolveUserDataDir('/home/x/.config', true)).toBe('/home/x/.config/@drop/desktop')
    expect(resolveUserDataDir('C:\\Users\\x\\AppData\\Roaming', true)).toContain('@drop')
  })
})
