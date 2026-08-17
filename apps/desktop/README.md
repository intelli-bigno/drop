# DROP 데스크톱 (Electron + React)

## 명령

| 명령 | 설명 |
| --- | --- |
| `pnpm dev:local` | 로컬 Supabase를 보는 개발 실행 |
| `pnpm dev:remote` | 리모트 Supabase를 보는 개발 실행 |
| `pnpm build:local` / `build:remote` | 번들 빌드 |
| `pnpm test:run` (레포 루트) | vitest |

구성값은 `apps/desktop/.env.localdev` / `.env.remote`로 흐른다. 실제 값이 든 파일은 커밋되지 않고, 견본 `.env.localdev.example`만 커밋한다.

## 로그인 없이 화면 띄우기 (BRU-71)

UI 변경을 눈으로 확인하려면 로그인 없이 앱을 띄울 수 있어야 한다. iOS의 `-dropPreview`와 같은 자리이고, 다른 점은 **인메모리 표본이 아니라 로컬 Supabase의 실제 세션**을 쓴다는 것이다 — "DB 컬럼이 화면까지 흘러오는지"를 보려는 것이라 쿼리 경로를 건너뛰면 증명되는 것이 없다.

```bash
supabase start          # 로컬 스택
supabase db reset       # 마이그레이션 + seed.sql (시드 사용자·표본 노트)
cp apps/desktop/.env.localdev.example apps/desktop/.env.localdev
pnpm dev:local
```

`.env.localdev`의 `VITE_DROP_PREVIEW=1`이 켜져 있으면 로그인 화면을 건너뛰고 시드 사용자(`preview@drop.local`)로 들어간다.

### 스크린샷 자동 촬영

`pnpm dev:local`이 띄우는 렌더러는 `http://localhost:5173`에서 **브라우저로도** 열린다. 프리뷰 모드는 Electron preload가 심는 `window.api` 자리를 흉내 내므로(`lib/preview-session.ts`) 브라우저에서 앱이 죽지 않고, Playwright 등으로 스크린샷을 찍을 수 있다.

흉내 내는 것은 모양뿐이다 — 자동 업데이트·빠른 캡처처럼 Electron이 해야 하는 일은 동작하지 않는다. 그 기능을 보려면 Electron 창에서 확인해야 한다.

### 프로덕션에는 들어가지 않는다

프리뷰 모듈은 **동적 import**로만 불린다 (`import.meta.env.DEV` 안에서). 정적 import로 두면 가드가 죽은 코드가 되어도 모듈이 번들에 남아 시드 계정 문자열이 배포본에 실린다 — 실제로 그렇게 만들었다가 grep으로 잡았다(BRU-71).

확인 방법:

```bash
pnpm --filter @drop/desktop build:local
grep -rc "preview@drop.local\|dropPreviewSignIn\|installPreviewApiShim" out/renderer/assets/
# 전부 0이어야 한다
```

## 워크트리에서 실행할 때

`pnpm install`이 Electron 바이너리 내려받기를 건너뛰면 `Error: Electron uninstall` 또는 `Library not loaded: Electron Framework`로 죽는다. 메인 체크아웃의 dist를 그대로 쓰면 된다:

```bash
rm -rf node_modules/electron/dist
ln -s <메인체크아웃>/node_modules/electron/dist node_modules/electron/dist
printf 'Electron.app/Contents/MacOS/Electron' > node_modules/electron/path.txt
```
