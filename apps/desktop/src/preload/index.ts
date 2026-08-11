import { contextBridge, ipcRenderer } from 'electron'

// Supabase를 renderer에서 직접 사용하므로 IPC 불필요
// 필요시 여기에 Electron 전용 API 추가 (파일 시스템 접근 등)

const api = {
  platform: process.platform,

  /**
   * 외부 URL을 시스템 기본 브라우저에서 엽니다.
   * 주의: window.open() 사용 금지 - Electron 창이 열림
   * 모든 웹 링크는 반드시 이 함수를 사용할 것
   */
  openExternal: (url: string) => ipcRenderer.invoke('shell:openExternal', url),
  instagram: {
    ensureLogin: (): Promise<boolean> => ipcRenderer.invoke('instagram:ensureLogin'),
    fetchPost: (url: string) => ipcRenderer.invoke('instagram:fetchPost', url),
  },
  youtube: {
    fetchOEmbed: (url: string) => ipcRenderer.invoke('youtube:fetchOEmbed', url),
  },
  quickCapture: {
    open: () => ipcRenderer.invoke('quickCapture:open'),
    close: () => ipcRenderer.invoke('quickCapture:close'),
    submit: (content: string): Promise<{ success: boolean; handledByMainWindow: boolean }> =>
      ipcRenderer.invoke('quickCapture:submit', content),
    /** QuickCapture에서 직접 저장 후 메인 윈도우에 refresh 알림 */
    notifyRefresh: (): Promise<void> => ipcRenderer.invoke('quickCapture:notifyRefresh'),
    onNoteCreated: (callback: (content: string) => void): (() => void) => {
      const handler = (_event: Electron.IpcRendererEvent, content: string) => callback(content)
      ipcRenderer.on('quickCapture:noteCreated', handler)
      return () => {
        ipcRenderer.removeListener('quickCapture:noteCreated', handler)
      }
    },
    /** 메인 윈도우에서 refresh 이벤트 수신 */
    onRefresh: (callback: () => void): (() => void) => {
      const handler = () => callback()
      ipcRenderer.on('quickCapture:refresh', handler)
      return () => {
        ipcRenderer.removeListener('quickCapture:refresh', handler)
      }
    },
  },
  auth: {
    onCallback: (callback: (url: string) => void): (() => void) => {
      const handler = (_event: Electron.IpcRendererEvent, url: string) => callback(url)
      ipcRenderer.on('auth:callback', handler)
      return () => {
        ipcRenderer.removeListener('auth:callback', handler)
      }
    },
  },
  updater: {
    check: () => ipcRenderer.invoke('updater:check'),
    download: () => ipcRenderer.invoke('updater:download'),
    install: () => ipcRenderer.invoke('updater:install'),
    getVersion: (): Promise<string> => ipcRenderer.invoke('updater:getVersion'),
    onChecking: (callback: () => void): (() => void) => {
      const handler = () => callback()
      ipcRenderer.on('updater:checking', handler)
      return () => ipcRenderer.removeListener('updater:checking', handler)
    },
    onAvailable: (callback: (info: unknown) => void): (() => void) => {
      const handler = (_event: Electron.IpcRendererEvent, info: unknown) => callback(info)
      ipcRenderer.on('updater:available', handler)
      return () => ipcRenderer.removeListener('updater:available', handler)
    },
    onNotAvailable: (callback: (info: unknown) => void): (() => void) => {
      const handler = (_event: Electron.IpcRendererEvent, info: unknown) => callback(info)
      ipcRenderer.on('updater:not-available', handler)
      return () => ipcRenderer.removeListener('updater:not-available', handler)
    },
    onError: (callback: (error: string) => void): (() => void) => {
      const handler = (_event: Electron.IpcRendererEvent, error: string) => callback(error)
      ipcRenderer.on('updater:error', handler)
      return () => ipcRenderer.removeListener('updater:error', handler)
    },
    onProgress: (callback: (progress: { percent: number }) => void): (() => void) => {
      const handler = (_event: Electron.IpcRendererEvent, progress: { percent: number }) =>
        callback(progress)
      ipcRenderer.on('updater:progress', handler)
      return () => ipcRenderer.removeListener('updater:progress', handler)
    },
    onDownloaded: (callback: (info: unknown) => void): (() => void) => {
      const handler = (_event: Electron.IpcRendererEvent, info: unknown) => callback(info)
      ipcRenderer.on('updater:downloaded', handler)
      return () => ipcRenderer.removeListener('updater:downloaded', handler)
    },
  },
}

contextBridge.exposeInMainWorld('api', api)

export type Api = typeof api
