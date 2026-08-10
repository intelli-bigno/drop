# DROP 개선 리뷰 — 2026-08-10

조사 방식: Claude Code Explore 에이전트 3개 병렬 (desktop / mobile / mcp+supabase), 리포 로컬 클론 후 정적 리뷰. Supabase 원격 프로젝트는 Intellieffect org에 없음(개인 계정 소재 또는 삭제 — 미확인).

## Index

- [Summary](#summary)
- [Raw A — Desktop (Electron)](#raw-a--desktop-electron)
- [Raw B — Mobile (Flutter)](#raw-b--mobile-flutter)
- [Raw C — MCP server + Supabase](#raw-c--mcp-server--supabase)

## Summary

### P0 — 보안 (원격 DB가 살아있으면 즉시)

1. **anon이 전 유저의 `mcp_api_key`·`pin_hash` 열람 가능** — `20260104061614_user_profiles_anon_access.sql` 정책은 row-level이라 컬럼 보호 안 됨. anon 키는 DMG/IPA에 포함되므로 사실상 공개. → 정책 drop + SECURITY DEFINER 헬퍼로 대체.
2. **Storage RLS 크로스테넌트** — `20260104060500` 의 anon 정책 3개는 호출자 키를 요청에 바인딩하지 않음 → 타 유저 첨부 읽기/삭제 가능.
3. **MCP API 키 평문 저장 + 엔트로피 ~12자 + 검증 오라클(`get_user_id_by_mcp_key`) + 레이트리밋 없음** → sha256 저장, prefix lookup, revocation 컬럼.
4. **클라이언트에 서드파티 API 키 포함** — OpenAI Whisper·알라딘/네이버/카카오 키가 `--dart-define`으로 바이너리에 박힘 → Supabase Edge Function 경유로 이전.
5. **SECURITY DEFINER 함수 22개 전부 `SET search_path` 미지정**, `mcp_remove_tags_from_note`는 소유권 체크 누락, Electron `shell.openExternal` 무검증.

### P1 — 기능 결함

- Android 릴리즈 manifest에 `INTERNET`/`RECORD_AUDIO` 권한 없음 → 릴리즈 APK는 네트워크·녹음 전부 불능인데 배포 파이프라인은 존재.
- 녹음 파일을 `finally`에서 무조건 삭제 → 업로드 실패 시 녹음 영구 유실.
- MCP 서버가 private 버킷에 `getPublicUrl` 사용 → 첨부 URL 전부 죽은 링크 (`createSignedUrl`로).
- MCP README 설치법이 실제 패키지명/필수 env와 불일치 → 따라하면 즉사.
- 노트 "잠금"은 코스메틱: 본문은 항상 클라이언트로 내려오고 PIN은 무염 SHA-256(10^6 공간).

### P2 — 품질/성능

- 테스트: desktop 5파일(~7%), mobile 0, mcp-server 0, RLS 테스트 0. CI는 typecheck/analyze만 — `pnpm test`·`flutter test` 미실행, `pnpm lint`는 config 의존성 미설치로 아예 깨짐.
- `loadNotes` 전량 로드(페이지네이션 없음) — desktop·mobile 동일.
- HTTP 타임아웃 전무 (Dio 기본값, Electron `net.request`).
- 구조: desktop main 1,185줄 god-file, mobile `note_card.dart` 1,195줄, `packages/shared`는 아무도 import 안 함.

## Raw A — Desktop (Electron)

1. CRITICAL — Anon RLS policy exposes every user's MCP API key and PIN hash. `supabase/migrations/20260104061614_user_profiles_anon_access.sql:6-8` — `FOR SELECT TO anon USING (mcp_api_key IS NOT NULL)` is row-level, not column-level; anon key ships inside the DMG at `apps/desktop/src/renderer/lib/supabase.ts:6`; leaked keys grant full note CRUD via `mcp_*` SECURITY DEFINER functions.
2. HIGH — MCP API keys stored in plaintext and validated by equality. `20260102005914_add_mcp_api_key.sql:7,117-131`.
3. HIGH — All 22 SECURITY DEFINER functions lack `SET search_path`. `20260102005914:18,57,85,102,120,...,609`.
4. HIGH — `shell:openExternal` IPC accepts arbitrary strings with zero validation. `apps/desktop/src/main/index.ts:724-726`; content originates from scraped Instagram HTML/JSON-LD; restrict to https/http/mailto.
5. HIGH — CI never runs tests or linter. `.github/workflows/ci.yml:24-38`; `package.json:11` uses watch-mode `vitest` (CI needs `vitest run`).
6. HIGH — `pnpm lint` broken: `eslint.config.js:1-2` imports `@eslint/js`/`typescript-eslint` not present in root `package.json:15-22`.
7. HIGH — Note "lock" is cosmetic; `notes-slice.ts:20-26` selects `*` incl. locked bodies; `pin-utils.ts:5-11` unsalted single SHA-256 of 4-6 digit PIN.
8. MEDIUM — `loadNotes` no pagination: 4 unbounded queries per refresh. `notes-slice.ts:18-75`.
9. MEDIUM — Main-process HTTP calls have no timeout (`index.ts:324`, aladin/google/kakao/naver book utils).
10. MEDIUM — 1,185-line main-process god-file (`src/main/index.ts`): Instagram parsing 100-700, IPC 723-895, windows 908-1075, OAuth 1076-1101, quick capture 1150-1185.
11. MEDIUM — Test coverage ~7% of desktop files; 0 for mcp-server.
12. LOW — Dead `relockAll` (`lock-slice.ts:31`); no `setWindowOpenHandler`/`will-navigate` guard on any BrowserWindow incl. Instagram login window (`index.ts:169,939,1057`); no CSP.
- Ancillary: `vitest.config.ts:6` global node env + per-file jsdom pragmas; root `node_modules` absent so suite can't run without `pnpm install`.

## Raw B — Mobile (Flutter)

1. CRITICAL — OpenAI API key shipped inside client binary. `lib/data/services/whisper_service.dart:19,77` + `.github/workflows/release.yml:187,292` + `lib/core/config/secrets.dart.example:10` — `--dart-define` constants recoverable via `strings`. Fix: Edge Function w/ user JWT.
2. Same key-in-client for book APIs — `book_search_service.dart:40` passes `aladinTTBKey` as query param (proxy/log leak too).
3. Android release functionally broken: main `AndroidManifest.xml:4` lacks `INTERNET` (debug/profile only) yet `release.yml:288` distributes release APK.
4. Android recording can never work: no `RECORD_AUDIO` (nor `READ_MEDIA_*`); `audio_recorder_service.dart:49` hasPermission always false on Android.
5. Zero tests in app; CI runs only `flutter analyze` (`ci.yml:73`).
6. Recorded audio deleted in `finally` → failed upload loses recording permanently. `recording_provider.dart:176-179`; `_attachAudioToNote` swallows failure `:262-264`; transcription failure writes '[음성 메모 - 변환 실패]' `:157`.
7. `WhisperService` no Dio timeouts, no 25MB guard, backoff sleeps after final attempt (`whisper_service.dart:40-53,72-80`).
8. `loadNotes()` fetches every note/attachment/tag, all filtering client-side. `notes_repository.dart:19-43`.
9. Services `new`-ed inside notifier (no DI) `recording_provider.dart:74-75`; 50ms metering timer copies full state list ~20×/s `:223-243`.
10. God widgets `note_card.dart` (1195 lines), `note_composer_sheet.dart` (880); `supabase_config.dart:12` defaults to localhost and only prints on empty anon key; `google_sign_in ^6.2.1` a major behind; launcher icons `android: false`.

## Raw C — MCP server + Supabase

1. CRITICAL — `user_profiles` readable by anon → leaks every user's MCP API key + PIN hash. `20260104061614:6-8`; `pin_hash` defined `20251231212335:20`. Fix: drop policy, SECURITY DEFINER helper.
2. CRITICAL — Storage RLS: `20260104060500:9-38` three `TO anon` policies never bind caller's own key → cross-tenant read + arbitrary delete of private `attachments` bucket.
3. HIGH — MCP key plaintext, ~12 chars (9 random bytes base64, `+/=` stripped before `left(...,12)` so can be shorter, non-uniform entropy). `20260102005914:6-7,31-34`. Store sha256 + prefix + created/last_used/revoked_at.
4. HIGH — All `mcp_*` SECURITY DEFINER functions lack `SET search_path`, grantable to anon/public. Only `20251230080200:23` pins it.
5. HIGH — `get_user_id_by_mcp_key` unauthenticated key-validation oracle, no rate limit/logging. `20260102005914:82-96`.
6. HIGH — `mcp_remove_tags_from_note` never checks note ownership. `20260102005914:417-441` (contrast `mcp_add_tags_to_note:397`).
7. HIGH — README instructs `npm install -g drop-mcp` + only `DROP_TOKEN`, but package is `@brxce/drop-mcp` and server hard-fails without `SUPABASE_URL`+`SUPABASE_ANON_KEY` (`src/supabase.ts:9-14`).
8. MEDIUM — SQL-level limits unbounded; zod caps client-side only (`notes.ts:45`, `search.ts:25` vs `mcp_list_notes p_limit`).
9. MEDIUM — `upload_from_path` reads any absolute path, no allowlist/size cap — prompt-injection exfil primitive. `attachments.ts:189-200`.
10. MEDIUM — `getPublicUrl` on private bucket → dead links. `attachments.ts:82,130`; bucket `public=false` `20251221082345:69-71`. Use `createSignedUrl`.
11. MEDIUM — Zero tests for mcp-server/shared, no CI job, no pgTAP/RLS tests.
12. LOW — Dead `login.ts`/`auth.ts` writes refresh token to `<pkg>/.env`; validated user id cached for process lifetime (revoked key keeps working); `packages/shared` never imported, `main`/`types` point at raw `.ts`.
