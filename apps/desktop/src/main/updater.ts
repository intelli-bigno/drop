import { app, dialog, BrowserWindow, ipcMain } from 'electron'
import { autoUpdater, type UpdateInfo } from 'electron-updater'
import log from 'electron-log'
import { markQuitting } from './quit-state'

// Configure logging
log.transports.file.level = 'info'
autoUpdater.logger = log

// Disable auto download - we'll prompt the user first
autoUpdater.autoDownload = false
autoUpdater.autoInstallOnAppQuit = true

let mainWindow: BrowserWindow | null = null

export function initAutoUpdater(window: BrowserWindow): void {
  mainWindow = window

  // Don't check for updates in development
  if (!app.isPackaged) {
    log.info('[updater] Skipping update check in development mode')
    return
  }

  // Check for updates on startup (after a short delay)
  setTimeout(() => {
    checkForUpdates()
  }, 3000)

  // Check for updates every 4 hours
  setInterval(
    () => {
      checkForUpdates()
    },
    4 * 60 * 60 * 1000
  )
}

export function checkForUpdates(): void {
  if (!app.isPackaged) {
    log.info('[updater] Skipping update check in development mode')
    return
  }

  log.info('[updater] Checking for updates...')
  autoUpdater.checkForUpdates().catch((err) => {
    log.error('[updater] Error checking for updates:', err)
  })
}

// Handle update events
autoUpdater.on('checking-for-update', () => {
  log.info('[updater] Checking for update...')
  sendToRenderer('updater:checking')
})

autoUpdater.on('update-available', (info: UpdateInfo) => {
  log.info('[updater] Update available:', info.version)
  sendToRenderer('updater:available', info)

  // Show dialog to user
  if (mainWindow) {
    dialog
      .showMessageBox(mainWindow, {
        type: 'info',
        title: 'Update Available',
        message: `A new version (${info.version}) is available.`,
        detail: 'Would you like to download it now?',
        buttons: ['Download', 'Later'],
        defaultId: 0,
        cancelId: 1,
      })
      .then((result) => {
        if (result.response === 0) {
          autoUpdater.downloadUpdate()
        }
      })
  }
})

autoUpdater.on('update-not-available', (info: UpdateInfo) => {
  log.info('[updater] Update not available. Current version is latest:', info.version)
  sendToRenderer('updater:not-available', info)
})

autoUpdater.on('error', (err) => {
  log.error('[updater] Error:', err)
  sendToRenderer('updater:error', err.message)
})

autoUpdater.on('download-progress', (progress) => {
  log.info(`[updater] Download progress: ${progress.percent.toFixed(1)}%`)
  sendToRenderer('updater:progress', progress)
})

autoUpdater.on('update-downloaded', (info: UpdateInfo) => {
  log.info('[updater] Update downloaded:', info.version)
  sendToRenderer('updater:downloaded', info)

  // Show dialog to user
  if (mainWindow) {
    dialog
      .showMessageBox(mainWindow, {
        type: 'info',
        title: 'Update Ready',
        message: 'Update has been downloaded.',
        detail: 'The application will restart to apply the update.',
        buttons: ['Restart Now', 'Later'],
        defaultId: 0,
        cancelId: 1,
      })
      .then((result) => {
        if (result.response === 0) {
          installUpdate()
        }
      })
  }
})

// 업데이트 설치 = 앱 종료 + 교체 + 재실행.
// markQuitting() 없이 호출하면 창 닫기가 숨기기로 가로채여 앱이 죽지 않고,
// ShipIt이 종료를 기다리며 무한 대기해 업데이트가 적용되지 않는다.
// isForceRunAfter=true 를 줘야 설치 후 앱이 다시 켜진다.
function installUpdate(): void {
  log.info('[updater] Quitting to install update')
  markQuitting()
  autoUpdater.quitAndInstall(false, true)
}

function sendToRenderer(channel: string, data?: unknown): void {
  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.webContents.send(channel, data)
  }
}

// IPC handlers for manual update checks from renderer
export function setupUpdaterIpc(): void {
  ipcMain.handle('updater:check', () => {
    checkForUpdates()
  })

  ipcMain.handle('updater:download', () => {
    autoUpdater.downloadUpdate()
  })

  ipcMain.handle('updater:install', () => {
    installUpdate()
  })

  ipcMain.handle('updater:getVersion', () => {
    return app.getVersion()
  })
}
