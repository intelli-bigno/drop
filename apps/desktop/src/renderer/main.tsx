import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App'
import './styles/index.css'
// 개발 전용 (BRU-71) — Electron 밖(브라우저)에서도 화면이 뜨게 window.api 자리를 채운다.
// 동적 import라 프로덕션 번들에는 이 모듈 자체가 들어가지 않는다.
if (import.meta.env.DEV) {
  const { installPreviewApiShim, isPreviewRequested } = await import('./lib/preview-session')
  if (isPreviewRequested()) installPreviewApiShim()
}

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
)
