import { defineConfig, mergeConfig, type ConfigEnv, type UserConfig } from 'vite'
import { resolve } from 'path'
import electronViteConfig from './electron.vite.config'

/**
 * 렌더러만 브라우저로 띄우는 dev 서버 (BRU-111).
 *
 * `electron-vite dev --rendererOnly`는 이름과 달리 **Electron 기동을 건너뛰지 않는다** —
 * main·preload 빌드만 건너뛰고 `out/main/index.js`를 찾으러 가서, 없으면
 * `No electron app entry file found`로 dev 서버까지 함께 죽는다 (electron-vite 2.3.0 실측).
 * 그래서 렌더러 설정만 떼어 순수 vite로 돌린다.
 *
 * 설정을 베껴 쓰지 않고 `electron.vite.config.ts`의 renderer 섹션을 **그대로 가져온다** —
 * alias·plugin이 두 벌이 되면 브라우저에서 통과한 것이 Electron에서 통과했다는 보장이 사라진다.
 */
export default defineConfig(async (env: ConfigEnv): Promise<UserConfig> => {
  const resolved = await (electronViteConfig as (env: ConfigEnv) => Promise<{
    renderer?: UserConfig
  }>)(env)

  return mergeConfig(resolved.renderer ?? {}, {
    // electron-vite가 renderer에 기본으로 주는 값들 — 순수 vite에는 직접 준다.
    root: resolve(__dirname, 'src/renderer'),
    // .env.localdev / .env.remote는 패키지 루트에 있다 (root가 src/renderer이므로 명시 필요).
    envDir: __dirname,
    server: { port: 5173, strictPort: false },
  } satisfies UserConfig)
})
