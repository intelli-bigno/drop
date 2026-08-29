# DROP 데스크톱 (Electron + React)

## 명령

| 명령 | 설명 |
| --- | --- |
| `pnpm dev:local` | 로컬 Supabase를 보는 개발 실행 |
| `pnpm dev:remote` | 리모트 Supabase를 보는 개발 실행 |
| `pnpm build:local` / `build:remote` | 번들 빌드 |
| `pnpm test:run` (레포 루트) | vitest |
| `make desktop-browser` (레포 루트) | 렌더러만 브라우저로 (Electron 창 없음, BRU-111) |

구성값은 `apps/desktop/.env.localdev` / `.env.remote`로 흐른다. 실제 값이 든 파일은 커밋되지 않고, 견본 `.env.localdev.example`만 커밋한다.

## 전역 퀵캡처 단축키 (BRU-84)

다른 앱을 쓰는 중에도 캡처 입력을 띄우는 OS 전역 단축키다. 기본 조합은 **⌥Space**이고,
개발 실행은 설치본의 조합을 빼앗지 않도록 **⌥⇧Space**를 쓴다.

- 변경: 사용자 메뉴 → **전역 단축키**. 다이얼로그에서 조합을 직접 눌러 지정한다.
  선택값은 `userData/settings.json`에 저장된다 (`quickCaptureShortcut`).
- **등록 실패는 조용히 넘어가지 않는다.** 사용자 지정 → 기본값 순으로 시도한다.
  판정 기준은 "무언가 잡혔는가(`ok`)"가 아니라 **"고른 그 조합이 잡혔는가(`preferredRegistered`)"** 다 —
  기본값으로 물러서서 잡힌 것을 성공으로 저장하면 사용자는 자기 조합이 먹는 줄 안다.
  고른 조합이 실패하면 설정을 저장하지 않고 직전 조합으로 되돌린 뒤 화면에 실패 사유를 붉게 남긴다.
  설정 화면은 `custom ≠ 실제 등록 조합`도 실패로 표시하고, 트레이 메뉴에서는 먹지 않는 조합 라벨을 지운다.
- **경고는 "다시 보지 않기"로 끌 수 있다.** ⌥Space는 Alfred 같은 앱이 흔히 점유해서
  매 실행마다 뜨면 상시 나그가 된다. 선택은 `userData/settings.json`의
  `suppressShortcutNotice`에 남고, 설정 화면의 실패 표시는 그대로 남는다.
- **설정 파일은 모르는 키를 지우지 않는다.** `parseSettings`는 아는 키만 정규화하고
  나머지는 원문 그대로 되쓴다 — 다른 버전이 추가한 설정이 조용히 사라지지 않게.
- **캡처를 닫으면 원래 앱으로 포커스가 돌아간다.** 전역 단축키로 열렸고 그때 앱이 포커스가
  아니었을 때만 `app.hide()`를 부른다 — 앱 안에서 연 캡처는 숨기지 않는다.

조합 규칙(정규화·검증·표시)은 `src/shared/shortcuts.ts`에 있다. Electron을 부르지 않는 순수
모듈이라 main·renderer가 같은 규칙을 쓰고, `pnpm test:run`으로 덮인다. 조합 녹음은
`event.key`가 아니라 `event.code`를 읽는다 — macOS에서 Option을 누르면 `key`가 `'å'` 같은
합성 문자로 바뀌어 조합을 알아볼 수 없기 때문이다.

## 로그인 없이 화면 띄우기 (BRU-71)

UI 변경을 눈으로 확인하려면 로그인 없이 앱을 띄울 수 있어야 한다. iOS의 `-dropPreview`와 같은 자리이고, 다른 점은 **인메모리 표본이 아니라 로컬 Supabase의 실제 세션**을 쓴다는 것이다 — "DB 컬럼이 화면까지 흘러오는지"를 보려는 것이라 쿼리 경로를 건너뛰면 증명되는 것이 없다.

```bash
supabase start          # 로컬 스택
supabase db reset       # 마이그레이션 + seed.sql (시드 사용자·표본 노트)
cp apps/desktop/.env.localdev.example apps/desktop/.env.localdev
pnpm dev:local
```

`.env.localdev`의 `VITE_DROP_PREVIEW=1`이 켜져 있으면 로그인 화면을 건너뛰고 시드 사용자(`preview@drop.local`)로 들어간다.

> `supabase db reset`은 로컬 DB를 통째로 다시 만든다. 옆에서 다른 작업이 같은 로컬 스택을 쓰고 있으면 그 상태가 지워진다 — 시드 사용자가 이미 있으면 실행하지 않는다.

## 브라우저로 화면 실측하기 (BRU-111)

Electron 창을 띄우지 않고 **렌더러만 브라우저로** 연다. 앱 재기동이 없어 화면 확인 사이클이 훨씬 짧다.

```bash
make desktop-browser    # → http://localhost:5173
```

전제(`.env.localdev`·`VITE_DROP_PREVIEW=1`·로컬 Supabase·시드 사용자)가 하나라도 없으면 **무엇이 없는지와 무엇을 하면 되는지를 찍고 멈춘다.** 시드 사용자 확인은 실제로 로그인 API를 때린다 — DB만 떠 있고 `seed.sql`이 안 들어간 상태가 가장 헷갈리는 실패였다.

`electron-vite dev --rendererOnly`를 쓰지 않는 이유: 이름과 달리 Electron 기동을 건너뛰지 않는다. main·preload 빌드만 건너뛰고 `out/main/index.js`를 찾으러 가서, 없으면 `No electron app entry file found`로 dev 서버까지 함께 죽는다 (2.3.0 실측). 그래서 `vite.browser.config.ts`가 `electron.vite.config.ts`의 renderer 섹션만 떼어 순수 vite로 돌린다 — 설정을 베끼지 않고 가져오므로 alias·plugin이 두 벌이 되지 않는다.

### 검증 도구는 `aside`다 (Playwright 아님)

이 레포에서 브라우저를 **에이전트가 직접 조작하는** 검증은 `aside` repl로 한다. Playwright는 코드로 쓰인 e2e 스위트를 돌릴 때만 쓴다.

```js
const page = await openTab('http://localhost:5173/')
console.log((await snapshot(page)).tree)
await page.screenshot({ path: './artifacts/feed.png' })
```

콘솔 에러를 놓치지 않으려면 수집기를 심어 두고 화면마다 확인한다. 화면이 죽으면 `#root`가 빈 채 하얘지므로, "스크린샷이 하얗다"가 곧 크래시 신호다.

```js
await page.evaluate(() => {
  window.__errs = []
  window.addEventListener('error', (e) => window.__errs.push(e.message))
  const ce = console.error.bind(console)
  console.error = (...a) => { window.__errs.push(a.map(String).join(' ')); ce(...a) }
})
// ... 화면 조작 ...
console.log(await page.evaluate(() => document.getElementById('root').innerHTML !== ''))
console.log(await page.evaluate(() => window.__errs))
```

퀵캡처 화면은 별도 창이 아니라 해시 라우트다 — 브라우저에서는 `http://localhost:5173/#quick-capture`로 직접 들어간다.

**브라우저 확장이 키를 가로챈다.** Aside Browser에는 Vimium이 붙어 있어 `?`(단축키 치트시트)를 누르면 Vimium 도움말이 뜬다. 치트시트는 `⌘/`로 연다. 단축키를 실측할 때 "안 먹는다"의 원인이 앱이 아닐 수 있다.

### 브라우저에서 확인한 화면 (2026-08-25 실측)

피드·노트 카드(액션 버튼 줄)·보관함·휴지통·검색·태그 관리·프로젝트 지정·댓글·편집 기록·단축키 치트시트·사용자 메뉴(버전 표시·업데이트 확인·MCP 토큰 복사)·전역 단축키 다이얼로그·퀵캡처 해시 라우트.

### 브라우저에서 **확인할 수 없는** 것

여기서 통과했다고 Electron에서 통과한 것이 아니다. `window.api` shim은 모양만 흉내 내고, 대응물이 없는 자리는 **일부러 실패를 돌려준다**(성공한 척하면 화면이 "됐다"고 표시해 버린다). 아래는 반드시 Electron 창에서 확인한다:

- **전역 퀵캡처 단축키** (Ctrl 더블 탭, BRU-103) — OS 전역 후킹. 설정 화면은 브라우저에서 항상 "등록 안 됨"으로 뜨는 것이 정상이다.
- **자동 업데이트** — check/download/install 전 과정. 브라우저에서는 이벤트가 오지 않아 "개발 빌드에서는 업데이트를 확인하지 않습니다"만 보인다.
- **퀵캡처 창** — 별도 BrowserWindow 띄우기·닫기, 닫을 때 원래 앱으로 포커스 복귀.
- **외부 링크 열기** — `shell.openExternal`. 브라우저에서는 콘솔에 찍기만 한다.
- **Google 로그인** — `drop://` 커스텀 프로토콜 콜백이 브라우저에는 오지 않는다.
- **인스타그램 수집** — 숨은 BrowserWindow 경유. 브라우저에서는 CORS로 막힌다.
- **네이티브 첨부·파일 드롭·트레이 메뉴·창 상태**.

### 프로덕션에는 들어가지 않는다

프리뷰 모듈은 **동적 import**로만 불린다 (`import.meta.env.DEV` 안에서). 정적 import로 두면 가드가 죽은 코드가 되어도 모듈이 번들에 남아 시드 계정 문자열이 배포본에 실린다 — 실제로 그렇게 만들었다가 grep으로 잡았다(BRU-71).

확인 방법:

```bash
pnpm --filter @drop/desktop build:local
grep -rc "preview@drop.local\|dropPreviewSignIn\|installPreviewApiShim" out/renderer/assets/
# 전부 0이어야 한다
```

## 릴리스 버전의 정본은 태그다 (BRU-192)

`package.json`의 `version`은 **배포에 쓰이지 않는다.** `.github/workflows/release.yml`이
태그에서 값을 뽑아 빌드 직전에 덮어쓴다:

```yaml
VERSION=${GITHUB_REF#refs/tags/v}
npm version $VERSION --no-git-tag-version --allow-same-version
```

여기 적힌 값은 **로컬 개발 빌드가 화면(사용자 메뉴)에 보여줄 때만** 쓰인다. 그래서 최신
릴리스와 맞춰 두지만, 이 값을 올린다고 릴리스가 되지는 않는다.

한때 `make release`가 이 값에서 patch를 올렸다. 아무도 관리하지 않아 0.0.9에 머물러
있었고 태그는 v1.0.34까지 가 있어서, `make release`가 이미 존재하는 옛 태그 v0.0.10을
만들려다 멈췄다. 멈춘 것이 다행이었다 — 성공했다면 최신보다 낮은 버전이 발행되고,
electron-updater는 semver 역행을 **조용히 무시하므로** 아무도 업데이트를 못 받은 채
릴리스는 성공한 것처럼 보였을 것이다.

지금은 `scripts/release-version.mjs`가 태그에서 다음 버전을 계산하고 역행을 막는다.
`make release`와 `make release-local`이 둘 다 그것을 본다.

```bash
make release-dry-run   # 다음 버전만 확인
make release           # 최신 태그 + 1 로 태그·push
```

## 워크트리에서 실행할 때

`pnpm install`이 Electron 바이너리 내려받기를 건너뛰면 `Error: Electron uninstall` 또는 `Library not loaded: Electron Framework`로 죽는다. 메인 체크아웃의 dist를 그대로 쓰면 된다:

```bash
rm -rf node_modules/electron/dist
ln -s <메인체크아웃>/node_modules/electron/dist node_modules/electron/dist
printf 'Electron.app/Contents/MacOS/Electron' > node_modules/electron/path.txt
```

`make desktop-browser`는 Electron 바이너리를 쓰지 않는다 — 위 심볼릭 링크 없이도 워크트리에서 바로 돈다.
