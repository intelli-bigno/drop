import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App'
import './styles/index.css'
// 개발 전용 (BRU-71) — Electron 밖(브라우저)에서도 화면이 뜨게 window.api 자리를 채운다.
// 동적 import라 프로덕션 번들에는 이 모듈 자체가 들어가지 않는다.
// 쇼케이스(#styleguide)도 Electron 밖에서 열리므로 같은 shim이 필요하다 (BRU-172) —
// 전역 단축키 설정처럼 window.api를 쓰는 컴포넌트가 진열돼 있다.
if (import.meta.env.DEV) {
  const { installPreviewApiShim, isPreviewRequested } = await import('./lib/preview-session')
  const isStyleguide = window.location.hash.replace('#', '').startsWith('styleguide')
  if (isPreviewRequested() || isStyleguide) installPreviewApiShim()
}

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
)
