import { describe, expect, it } from 'vitest'
import { USER_DATA_DIR_NAME, resolveUserDataDir } from './user-data'

describe('resolveUserDataDir', () => {
  it('pins the directory name to DROP — the identifier existing installs already use', () => {
    // productName을 Braindump로 바꾼 뒤에도 기존 설치본의 세션·설정이 살아 있어야 한다.
    expect(USER_DATA_DIR_NAME).toBe('DROP')
    expect(resolveUserDataDir('/Users/x/Library/Application Support', true)).toBe(
      '/Users/x/Library/Application Support/DROP'
    )
  })

  it('keeps development runs in their own directory so they cannot clobber the install', () => {
    expect(resolveUserDataDir('/Users/x/Library/Application Support', false)).toBe(
      '/Users/x/Library/Application Support/DROP-dev'
    )
  })

  it('works off macOS too — the same name under whatever appData the platform gives', () => {
    expect(resolveUserDataDir('C:\\Users\\x\\AppData\\Roaming', true)).toContain('DROP')
    expect(resolveUserDataDir('/home/x/.config', true)).toBe('/home/x/.config/DROP')
  })
})
