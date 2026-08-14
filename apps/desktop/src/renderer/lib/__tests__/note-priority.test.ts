import { describe, it, expect } from 'vitest'
import { nextPriority, priorityClassName, PRIORITY_LEVELS } from '../note-priority'

describe('nextPriority', () => {
  it('should advance 0 to 1', () => {
    expect(nextPriority(0)).toBe(1)
  })

  it('should advance 1 to 2', () => {
    expect(nextPriority(1)).toBe(2)
  })

  it('should advance 2 to 3', () => {
    expect(nextPriority(2)).toBe(3)
  })

  it('should wrap 3 back to 0', () => {
    expect(nextPriority(3)).toBe(0)
  })

  it('should cycle through every level and return to the start', () => {
    let priority = 0
    for (let i = 0; i < PRIORITY_LEVELS; i += 1) {
      priority = nextPriority(priority)
    }
    expect(priority).toBe(0)
  })
})

describe('priorityClassName', () => {
  it('should name the neutral level for priority 0', () => {
    expect(priorityClassName(0)).toBe('priority-none')
  })

  it('should name low, medium and high for 1, 2 and 3', () => {
    expect(priorityClassName(1)).toBe('priority-low')
    expect(priorityClassName(2)).toBe('priority-medium')
    expect(priorityClassName(3)).toBe('priority-high')
  })

  it('should fall back to the neutral level for unknown values', () => {
    expect(priorityClassName(99)).toBe('priority-none')
  })
})
