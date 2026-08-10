import { describe, it, expect } from 'vitest'
import { isSafeExternalUrl } from './url-utils'

describe('isSafeExternalUrl', () => {
  it('should allow http URLs', () => {
    expect(isSafeExternalUrl('http://example.com')).toBe(true)
    expect(isSafeExternalUrl('http://example.com/path?query=1')).toBe(true)
  })

  it('should allow https URLs', () => {
    expect(isSafeExternalUrl('https://example.com')).toBe(true)
    expect(isSafeExternalUrl('https://www.instagram.com/p/ABC123/')).toBe(true)
  })

  it('should allow mailto URLs', () => {
    expect(isSafeExternalUrl('mailto:user@example.com')).toBe(true)
  })

  it('should reject file URLs', () => {
    expect(isSafeExternalUrl('file:///etc/passwd')).toBe(false)
    expect(isSafeExternalUrl('file://localhost/Users/me/secret.txt')).toBe(false)
  })

  it('should reject smb URLs', () => {
    expect(isSafeExternalUrl('smb://attacker.com/share')).toBe(false)
  })

  it('should reject javascript URLs', () => {
    expect(isSafeExternalUrl('javascript:alert(1)')).toBe(false)
  })

  it('should reject custom scheme URLs', () => {
    expect(isSafeExternalUrl('drop://auth/callback')).toBe(false)
    expect(isSafeExternalUrl('vscode://extension/install')).toBe(false)
  })

  it('should reject invalid or empty input', () => {
    expect(isSafeExternalUrl('not-a-url')).toBe(false)
    expect(isSafeExternalUrl('')).toBe(false)
  })
})
