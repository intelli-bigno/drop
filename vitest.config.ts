import { configDefaults, defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
    include: ['**/*.test.ts'],
    // 워크트리는 머지될 때까지 `.claude/worktrees/` 아래 살아 있다(레포 규약).
    // 빼지 않으면 다른 브랜치의 낡은 사본까지 함께 돌아 통과 여부를 믿을 수 없다 —
    // 오늘 병렬 작업 5건에서 308파일/4126테스트가 나왔고 실제는 55/707이었다.
    // 기본 exclude(node_modules·dist 등)를 덮어쓰지 않도록 펼쳐서 더한다.
    exclude: [...configDefaults.exclude, '**/.claude/**'],
    coverage: {
      reporter: ['text', 'json', 'html'],
    },
  },
})
