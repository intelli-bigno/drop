.PHONY: help install setup test test-db db-test clean tokens tokens-check \
        electron-rebuild electron-dev electron-dev-local electron-dev-remote desktop-browser \
        electron-build electron-build-local electron-build-remote \
        ios-config ios-generate ios-test ios-build ios-build-remote ios-dev ios-dev-remote ios-open ios-clean \
        android-config android-config-remote android-test android-build android-install android-clean \
        ios-uitest \
        mobile-config mobile-test mobile-analyze mobile-build mobile-dev mobile-dev-remote mobile-clean

.DEFAULT_GOAL := help

# 도움말 출력
help:
	@echo "사용 가능한 명령어:"
	@echo ""
	@echo "  기본 설정"
	@echo "    make install              - pnpm 의존성 설치"
	@echo "    make setup                - install + electron-rebuild (최초 세팅)"
	@echo ""
	@echo "  테스트/정리"
	@echo "    make test                 - 테스트 실행"
	@echo "    make test-db              - database 패키지 테스트"
	@echo "    make db-test              - DB 트리거·함수 회귀 테스트 (pgTAP)"
	@echo "    make clean                - 빌드 산출물 및 node_modules 정리"
	@echo ""
	@echo "  디자인 토큰"
	@echo "    make tokens               - tokens.json → 데스크톱 CSS · iOS Swift · Android Kotlin · Flutter Dart 생성"
	@echo "    make tokens-check         - 생성물이 정본과 맞는지 검사 (CI용)"
	@echo ""
	@echo "  Electron (Desktop)"
	@echo "    make electron-rebuild     - better-sqlite3 Electron용 재빌드"
	@echo "    make electron-dev         - 개발 서버 실행"
	@echo "    make electron-dev-local   - 로컬 Supabase로 개발 서버"
	@echo "    make electron-dev-remote  - 리모트 Supabase로 개발 서버"
	@echo "    make electron-build       - 프로덕션 빌드"
	@echo "    make electron-build-local - 로컬 Supabase 설정으로 빌드"
	@echo "    make electron-build-remote - 리모트 Supabase 설정으로 빌드"
	@echo "    make desktop-browser      - 렌더러만 브라우저로 (aside 실측용, Electron 창 없음)"
	@echo ""
	@echo "  iOS (apps/ios)"
	@echo "    make ios-config           - 환경변수 → Config-*.xcconfig 생성"
	@echo "    make ios-generate         - project.yml → Drop.xcodeproj 생성"
	@echo "    make ios-test             - DropCore 테스트 (시뮬레이터 불필요)"
	@echo "    make ios-build            - 시뮬레이터용 빌드 (로컬 Supabase)"
	@echo "    make ios-build-remote     - 시뮬레이터용 빌드 (리모트 Supabase)"
	@echo "    make ios-dev              - 시뮬레이터에서 실행 (로컬 Supabase)"
	@echo "    make ios-dev-remote       - 시뮬레이터에서 실행 (리모트 Supabase)"
	@echo "    make ios-open             - Xcode로 열기"
	@echo "    make ios-clean            - 생성물 정리"
	@echo ""
	@echo "  Android (apps/android)"
	@echo "    make android-config       - 환경변수 → apps/android/local.properties 생성"
	@echo "    make android-config-remote - 같은 것, 리모트 Supabase 값으로"
	@echo "    make android-test         - core 모듈 JVM 테스트 (에뮬레이터 불필요)"
	@echo "    make android-build        - 디버그 APK 빌드"
	@echo "    make android-install      - 연결된 기기·에뮬레이터에 설치"
	@echo "    make android-clean        - 생성물 정리"
	@echo ""
	@echo "  Mobile — Flutter (apps/mobile, BRU-152 재구축 트랙)"
	@echo "    make mobile-config        - 환경변수 → .config/{local,remote}.json 생성"
	@echo "    make mobile-test          - drop_core dart test + 앱 위젯 테스트 (에뮬레이터 불필요)"
	@echo "    make mobile-analyze       - dart analyze (drop_core + 앱)"
	@echo "    make mobile-dev           - 시뮬레이터에서 실행 (로컬 Supabase)"
	@echo "    make mobile-dev-remote    - 시뮬레이터에서 실행 (리모트 Supabase)"
	@echo "    make mobile-build         - iOS 시뮬레이터용 빌드"
	@echo "    make mobile-clean         - 생성물 정리"

# ============================================
# 기본 설정
# ============================================

# 의존성 설치
install:
	pnpm install --ignore-scripts

# 설치 + 재빌드 (최초 세팅)
setup: install electron-rebuild

# 테스트 실행
test:
	pnpm test

# database 패키지 테스트
test-db:
	pnpm --filter @drop/database test

# DB 트리거·함수 회귀 테스트 (pgTAP). 로컬 Supabase가 떠 있어야 한다.
db-test:
	supabase test db

# 빌드 산출물 정리
clean:
	rm -rf node_modules
	rm -rf apps/*/node_modules apps/*/out apps/*/dist
	rm -rf packages/*/node_modules packages/*/dist

# ============================================
# Electron (Desktop)
# ============================================

DESKTOP_DIR := apps/desktop

# better-sqlite3를 Electron용으로 재빌드
electron-rebuild:
	cd node_modules/better-sqlite3 && \
	HOME=~/.electron-gyp npx node-gyp rebuild --release \
		--target=33.4.3 \
		--arch=arm64 \
		--dist-url=https://electronjs.org/headers

# 개발 서버 실행
electron-dev:
	pnpm dev

# 개발 서버 실행 (로컬 Supabase)
electron-dev-local:
	pnpm dev:local

# 개발 서버 실행 (리모트 Supabase)
electron-dev-remote:
	pnpm dev:remote

# 프로덕션 빌드
electron-build:
	pnpm build

# 빌드 (로컬 Supabase 설정)
electron-build-local:
	pnpm build:local

# 빌드 (리모트 Supabase 설정)
electron-build-remote:
	pnpm build:remote

# ============================================
# 브라우저로 렌더러만 띄우기 (BRU-111) — aside repl 실측 경로
# ============================================
# Electron 창을 띄우지 않고 렌더러만 vite로 서빙한다. 화면 변경을 눈으로 확인하는
# 사이클이 Electron 재기동보다 훨씬 빠르다.
#
# 여기서 통과한 것이 Electron에서 통과한 것은 아니다 — 전역 단축키(Ctrl 더블 탭)·
# 자동 업데이트·퀵캡처 창·네이티브 첨부는 브라우저에 대응물이 없다.
# 무엇이 검증되지 않는지는 apps/desktop/README.md에 적어 두었다.
#
# `electron-vite dev --rendererOnly`를 쓰지 않는 이유: 이름과 달리 Electron 기동을
# 건너뛰지 않아 out/main/index.js가 없으면 dev 서버까지 함께 죽는다 (2.3.0 실측).
desktop-browser:
	@test -x node_modules/.bin/vite || { \
		echo "✗ vite가 없습니다 (node_modules/.bin/vite)."; \
		echo "  → pnpm install"; \
		exit 1; }
	@test -f $(DESKTOP_DIR)/.env.localdev || { \
		echo "✗ $(DESKTOP_DIR)/.env.localdev 가 없습니다."; \
		echo "  → cp $(DESKTOP_DIR)/.env.localdev.example $(DESKTOP_DIR)/.env.localdev"; \
		exit 1; }
	@grep -q '^VITE_DROP_PREVIEW=1' $(DESKTOP_DIR)/.env.localdev || { \
		echo "✗ $(DESKTOP_DIR)/.env.localdev 에 VITE_DROP_PREVIEW=1 이 없습니다."; \
		echo "  → 없으면 로그인 화면에서 멈춘다 (브라우저에는 Google OAuth 콜백이 오지 않는다)."; \
		exit 1; }
	@supabase status >/dev/null 2>&1 || { \
		echo "✗ 로컬 Supabase가 떠 있지 않습니다."; \
		echo "  → supabase start"; \
		exit 1; }
	@API=$$(grep '^VITE_SUPABASE_URL=' $(DESKTOP_DIR)/.env.localdev | cut -d= -f2-); \
	ANON=$$(grep '^VITE_SUPABASE_ANON_KEY=' $(DESKTOP_DIR)/.env.localdev | cut -d= -f2-); \
	CODE=$$(curl -s -o /dev/null -w '%{http_code}' -X POST "$$API/auth/v1/token?grant_type=password" \
		-H "apikey: $$ANON" -H 'Content-Type: application/json' \
		-d '{"email":"preview@drop.local","password":"drop-preview-password"}'); \
	test "$$CODE" = "200" || { \
		echo "✗ 시드 사용자(preview@drop.local)로 로그인할 수 없습니다 (HTTP $$CODE)."; \
		echo "  → supabase db reset  # 마이그레이션 + seed.sql 을 다시 넣는다 (로컬 DB 내용은 지워진다)"; \
		exit 1; }
	@echo "→ http://localhost:5173 (Electron 창은 뜨지 않는다)"
	pnpm exec vite --config $(DESKTOP_DIR)/vite.browser.config.ts --mode localdev

# ============================================
# iOS (apps/ios) — SwiftUI 네이티브. Flutter 앱은 BRU-22에서 제거됐다.
# ============================================

# xcode-select가 CommandLineTools를 가리키고 있어 명시가 필요하다.
IOS_DEVELOPER_DIR := /Applications/Xcode.app/Contents/Developer
IOS_DIR := apps/ios
IOS_SIMULATOR ?= platform=iOS Simulator,name=iPhone 17

# 환경변수 → Config-*.xcconfig 생성 (실제 값이 든 파일은 커밋되지 않는다)
# 필요한 값: SUPABASE_URL_LOCAL / SUPABASE_ANON_KEY_LOCAL / SUPABASE_URL_REMOTE / SUPABASE_ANON_KEY_REMOTE
# (이름은 과거 Flutter 타겟과 같다 — 기존 .env.local을 그대로 재사용할 수 있게)
ios-config:
	@bash scripts/ios-config.sh

# project.yml → Drop.xcodeproj 생성 (.xcodeproj는 커밋하지 않는다)
ios-generate:
	@command -v xcodegen >/dev/null || { echo "❌ xcodegen이 없습니다: brew install xcodegen"; exit 1; }
	@test -f $(IOS_DIR)/Config/Config-localdev.xcconfig || { echo "❌ Config-localdev.xcconfig가 없습니다 → make ios-config"; exit 1; }
	@test -f $(IOS_DIR)/Config/Config-remote.xcconfig || { echo "❌ Config-remote.xcconfig가 없습니다 → make ios-config"; exit 1; }
	cd $(IOS_DIR) && xcodegen generate

# 도메인 로직 테스트 — 시뮬레이터 없이 돈다
ios-test:
	cd $(IOS_DIR)/Packages/DropCore && DEVELOPER_DIR=$(IOS_DEVELOPER_DIR) swift test

# 화면을 실제로 조작하는 검증 (BRU-78) — 시뮬레이터가 필요하고 느리다.
# ios-test와 일부러 갈라 둔다: 시뮬레이터 없이 도는 빠른 피드백이 TDD 사이클의 전제다.
IOS_UITEST_SIMULATOR ?= platform=iOS Simulator,name=iPhone 17

ios-uitest: ios-generate
	cd $(IOS_DIR) && DEVELOPER_DIR=$(IOS_DEVELOPER_DIR) xcodebuild \
		-project Drop.xcodeproj -scheme Drop-localdev \
		-destination '$(IOS_UITEST_SIMULATOR)' test

# 시뮬레이터용 빌드 (기본: 로컬 Supabase)
IOS_SCHEME ?= Drop-localdev

ios-build: ios-generate
	cd $(IOS_DIR) && DEVELOPER_DIR=$(IOS_DEVELOPER_DIR) xcodebuild \
		-project Drop.xcodeproj -scheme $(IOS_SCHEME) \
		-destination 'generic/platform=iOS Simulator' build

# 리모트 Supabase를 보는 빌드
ios-build-remote:
	$(MAKE) ios-build IOS_SCHEME=Drop-remote

# 시뮬레이터에서 실행
ios-dev: ios-generate
	cd $(IOS_DIR) && DEVELOPER_DIR=$(IOS_DEVELOPER_DIR) xcodebuild \
		-project Drop.xcodeproj -scheme $(IOS_SCHEME) \
		-destination '$(IOS_SIMULATOR)' build

ios-dev-remote:
	$(MAKE) ios-dev IOS_SCHEME=Drop-remote

# Xcode로 열기
ios-open: ios-generate
	open $(IOS_DIR)/Drop.xcodeproj

ios-clean:
	rm -rf $(IOS_DIR)/Drop.xcodeproj $(IOS_DIR)/Packages/*/.build

# ============================================
# 디자인 토큰 (design-system/drop/tokens.json)
# ============================================
# 색·간격·타이포의 정본은 JSON 하나다. 여기서 네 앱의 토큰 파일이 생성된다:
#   apps/desktop/.../styles/tokens.css · DropUI/DropTokens.swift · android/.../DropTokens.kt
#   · apps/mobile/lib/theme/drop_tokens.g.dart
#
# 생성물은 커밋한다 — iOS·Android 빌드가 Node에 의존하면 안 되기 때문이다.
# CI는 tokens-check로 "재생성하면 diff가 없는지"만 본다.

tokens:
	@node scripts/build-tokens.mjs

# 생성물이 정본과 어긋난 채 머지되는 것을 막는다 (CI용)
tokens-check:
	@node scripts/build-tokens.mjs --check

# ============================================
# Android (apps/android) — Jetpack Compose 네이티브. 트랙 BRU-36 (하위 BRU-38~42)
# ============================================

ANDROID_DIR := apps/android

# 환경변수 → apps/android/local.properties (커밋되지 않는다)
# 필요한 값: SUPABASE_URL_LOCAL / SUPABASE_ANON_KEY_LOCAL (iOS 타겟과 같은 이름)
android-config:
	@bash scripts/android-config.sh local

android-config-remote:
	@bash scripts/android-config.sh remote

# 도메인 로직 테스트 — Android SDK도 에뮬레이터도 필요 없다 (ios-test와 같은 자리)
android-test:
	cd $(ANDROID_DIR) && ./gradlew :core:test

# 디버그 APK. Android SDK 경로는 ANDROID_HOME 또는 local.properties 의 sdk.dir 에서 온다.
android-build:
	cd $(ANDROID_DIR) && ./gradlew :app:assembleDebug

android-install:
	cd $(ANDROID_DIR) && ./gradlew :app:installDebug

android-clean:
	cd $(ANDROID_DIR) && ./gradlew clean

# ============================================
# Mobile — Flutter (BRU-152 재구축 트랙. iOS 구현 상태가 스펙)
# ============================================

MOBILE_DIR := apps/mobile

mobile-config:
	./scripts/mobile-config.sh

# 에뮬레이터 없이 도는 빠른 피드백이 TDD 사이클의 전제다 (ios-test와 같은 규율).
mobile-test:
	cd $(MOBILE_DIR)/packages/drop_core && dart test
	cd $(MOBILE_DIR) && flutter test

mobile-analyze:
	cd $(MOBILE_DIR)/packages/drop_core && dart analyze --fatal-infos
	cd $(MOBILE_DIR) && flutter analyze

mobile-dev:
	@test -f $(MOBILE_DIR)/.config/local.json || { echo "❌ .config/local.json이 없습니다 → make mobile-config"; exit 1; }
	cd $(MOBILE_DIR) && flutter run --dart-define-from-file=.config/local.json

mobile-dev-remote:
	@test -f $(MOBILE_DIR)/.config/remote.json || { echo "❌ .config/remote.json이 없습니다 → make mobile-config"; exit 1; }
	cd $(MOBILE_DIR) && flutter run --dart-define-from-file=.config/remote.json

mobile-build:
	cd $(MOBILE_DIR) && flutter build ios --simulator

mobile-clean:
	cd $(MOBILE_DIR) && flutter clean

# ============================================
# Release — 서명·공증 DMG → GitHub Releases (설치본 자동 업데이트 채널)
# ============================================

# 표준 경로: patch 버전 범프 → 커밋 + 태그 + push → GitHub Actions가 서명·공증·발행.
# mac과 iOS가 한 번에 나가고, 설치본은 latest-mac.yml을 보고 자동 업데이트한다.
release:
	@test "$$(git rev-parse --abbrev-ref HEAD)" = "main" || { echo "✗ main에서만 릴리스한다 (현재: $$(git rev-parse --abbrev-ref HEAD))"; exit 1; }
	@test -z "$$(git status --porcelain)" || { echo "✗ 워킹트리가 깨끗해야 한다"; exit 1; }
	@git pull --ff-only
	cd apps/desktop && npm version patch --no-git-tag-version
	@VERSION=$$(node -p "require('./apps/desktop/package.json').version"); \
	git add apps/desktop/package.json && \
	git commit -m "chore(release): v$$VERSION" && \
	git tag "v$$VERSION" && \
	git push && git push origin "v$$VERSION" && \
	echo "→ v$$VERSION 태그 push 완료 — GitHub Actions에서 빌드·공증·발행 진행 (gh run watch)"

# 비상용: CI가 죽었을 때 로컬 맥에서 현재 버전 그대로 빌드·서명·공증 후 같은 릴리스에 업로드.
# 버전 범프도 태그도 하지 않는다 — 태그는 항상 `make release`가 만든다.
# 자격증명은 1Password(op)에서 주입. 공증 실패 시: make release-local NOTARIZE=false
NOTARIZE ?= true
release-local:
	@VERSION=$$(node -p "require('./apps/desktop/package.json').version"); \
	echo "→ v$$VERSION 로컬 빌드·서명·발행 (notarize=$(NOTARIZE))"; \
	export APPLE_ID=$$(op item get "Apple App-Specific Password" --vault "Dev Credentials" --fields apple_id); \
	export APPLE_APP_SPECIFIC_PASSWORD=$$(op item get "Apple App-Specific Password" --vault "Dev Credentials" --fields credential --reveal); \
	export APPLE_TEAM_ID=$$(op item get "Apple App-Specific Password" --vault "Dev Credentials" --fields team_id); \
	export GH_TOKEN=$$(gh auth token); \
	cd apps/desktop && pnpm exec electron-vite build --mode remote && \
	pnpm exec electron-builder --mac --publish always -c.mac.notarize=$(NOTARIZE)

# 최초 1회: 빌드된 앱을 /Applications 에 설치 (이후는 앱 내 자동 업데이트)
install-local:
	rm -rf /Applications/DROP.app
	rm -rf /Applications/Braindump.app
	cp -R apps/desktop/release/mac-arm64/DROP.app /Applications/
	@echo "→ /Applications/DROP.app 설치 완료"
