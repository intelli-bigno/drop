import { defineConfig, externalizeDepsPlugin } from 'electron-vite'
import react from '@vitejs/plugin-react'
import { resolve } from 'path'
import { config } from 'dotenv'
import { cpSync } from 'fs'
import type { Plugin } from 'vite'

/**
 * uiohook-napi(네이티브, BRU-103)를 out/main/node_modules로 복사한다.
 *
 * 이 레포의 electron-builder는 node_modules를 통째로 제외하고 out만 싣는데,
 * 네이티브 모듈은 rollup으로 번들할 수 없다. prod dependencies로 두면
 * electron-builder의 pnpm 의존성 수집이 깨지므로(dependency path is undefined),
 * devDependencies에 두고 빌드 산출물에 직접 복사한다. .node 바이너리는
 * electron-builder smartUnpack이 asar 밖으로 빼 준다.
 */
function copyUiohookPlugin(): Plugin {
  return {
    name: 'copy-uiohook-napi',
    closeBundle() {
      const rootModules = resolve(__dirname, '../../node_modules')
      const dest = resolve(__dirname, 'out/main/node_modules')
      for (const pkg of ['uiohook-napi', 'node-gyp-build']) {
        cpSync(resolve(rootModules, pkg), resolve(dest, pkg), {
          recursive: true,
          dereference: true,
          // .bin 심볼릭 링크는 asar가 거부하고, 네이티브 소스는 실행에 불필요하다.
          filter: (source) =>
            !/\/(\.bin|src|libuiohook)(\/|$)/.test(source) && !source.endsWith('binding.gyp'),
        })
      }
    },
  }
}

export default defineConfig(({ mode }) => {
  // Load .env file based on mode
  const envFile = mode === 'localdev' ? '.env.localdev' : '.env.remote'
  config({ path: resolve(__dirname, envFile) })

  return {
    main: {
      plugins: [
        externalizeDepsPlugin({ exclude: ['@drop/database', '@drop/shared'] }),
        copyUiohookPlugin(),
      ],
      build: {
        rollupOptions: {
          // 네이티브 모듈은 번들에 넣지 않는다 — 바이너리는 electron-builder files로 실어 나른다.
          external: ['better-sqlite3', 'uiohook-napi'],
        },
      },
    },
    preload: {
      plugins: [externalizeDepsPlugin({ exclude: ['@drop/shared'] })],
    },
    renderer: {
      resolve: {
        alias: {
          '@renderer': resolve('src/renderer'),
        },
      },
      plugins: [react()],
    },
  }
})
