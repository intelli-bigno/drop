import eslint from '@eslint/js'
import tseslint from 'typescript-eslint'
import reactHooks from 'eslint-plugin-react-hooks'
import globals from 'globals'

export default tseslint.config(
  eslint.configs.recommended,
  ...tseslint.configs.recommended,
  {
    ignores: ['**/dist/**', '**/node_modules/**', '**/out/**'],
  },
  {
    // Node에서 직접 실행하는 스크립트 (빌드·검증용)
    files: ['**/scripts/**/*.mjs', '*.config.js'],
    languageOptions: {
      globals: globals.node,
    },
  },
  {
    plugins: { 'react-hooks': reactHooks },
    rules: {
      ...reactHooks.configs.recommended.rules,
      // 신규 도입 룰은 기존 코드 정리 전까지 경고로 유지
      'react-hooks/set-state-in-effect': 'warn',
      'react-hooks/use-memo': 'warn',
      // Electron preload 타입 참조는 triple-slash가 관례
      '@typescript-eslint/triple-slash-reference': 'off',
    },
  }
)
