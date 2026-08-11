import { defineConfig, externalizeDepsPlugin } from 'electron-vite'
import react from '@vitejs/plugin-react'
import { resolve } from 'path'
import { config } from 'dotenv'

export default defineConfig(({ mode }) => {
  // Load .env file based on mode
  const envFile = mode === 'localdev' ? '.env.localdev' : '.env.remote'
  config({ path: resolve(__dirname, envFile) })

  return {
    main: {
      plugins: [externalizeDepsPlugin({ exclude: ['@drop/database', '@drop/shared'] })],
      build: {
        rollupOptions: {
          external: ['better-sqlite3'],
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
