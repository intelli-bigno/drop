.PHONY: help install setup test test-db clean \
        electron-rebuild electron-dev electron-dev-local electron-dev-remote \
        electron-build electron-build-local electron-build-remote \
        flutter-setup flutter-dev flutter-dev-remote flutter-build flutter-build-ipa flutter-testflight \
        flutter-analyze flutter-test flutter-codegen flutter-clean \
        ios-generate ios-test ios-build ios-dev ios-open ios-clean

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
	@echo "    make clean                - 빌드 산출물 및 node_modules 정리"
	@echo ""
	@echo "  Electron (Desktop)"
	@echo "    make electron-rebuild     - better-sqlite3 Electron용 재빌드"
	@echo "    make electron-dev         - 개발 서버 실행"
	@echo "    make electron-dev-local   - 로컬 Supabase로 개발 서버"
	@echo "    make electron-dev-remote  - 리모트 Supabase로 개발 서버"
	@echo "    make electron-build       - 프로덕션 빌드"
	@echo "    make electron-build-local - 로컬 Supabase 설정으로 빌드"
	@echo "    make electron-build-remote - 리모트 Supabase 설정으로 빌드"
	@echo ""
	@echo "  Flutter (Mobile)"
	@echo "    make flutter-setup        - Flutter 의존성 설치 + 코드 생성"
	@echo "    make flutter-dev          - 로컬 Supabase로 Flutter 실행"
	@echo "    make flutter-dev-remote   - 리모트 Supabase로 Flutter 실행"
	@echo "    make flutter-build        - iOS 시뮬레이터용 빌드"
	@echo "    make flutter-build-ipa    - TestFlight용 IPA 빌드 (remote 자동)"
	@echo "    make flutter-testflight   - TestFlight 빌드+배포 (remote 자동)"
	@echo "    make flutter-analyze      - Flutter 코드 분석"
	@echo "    make flutter-test         - Flutter 테스트"
	@echo "    make flutter-codegen      - Flutter 코드 재생성"
	@echo "    make flutter-clean        - Flutter 정리"
	@echo ""
	@echo "  iOS 네이티브 (Flutter 대체 트랙)"
	@echo "    make ios-generate         - project.yml → Drop.xcodeproj 생성"
	@echo "    make ios-test             - DropCore 테스트 (시뮬레이터 불필요)"
	@echo "    make ios-build            - 시뮬레이터용 빌드"
	@echo "    make ios-dev              - 시뮬레이터에서 실행"
	@echo "    make ios-open             - Xcode로 열기"
	@echo "    make ios-clean            - 생성물 정리"

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

# 빌드 산출물 정리
clean:
	rm -rf node_modules
	rm -rf apps/*/node_modules apps/*/out apps/*/dist
	rm -rf packages/*/node_modules packages/*/dist

# ============================================
# Electron (Desktop)
# ============================================

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
# Flutter (Mobile)
# ============================================

# Flutter 의존성 설치 + 코드 생성
flutter-setup:
	cd apps/mobile && flutter pub get && dart run build_runner build --delete-conflicting-outputs

# Flutter 개발 서버 (로컬 Supabase)
# 환경변수: SUPABASE_URL_LOCAL, SUPABASE_ANON_KEY_LOCAL, GOOGLE_WEB_CLIENT_ID, GOOGLE_IOS_CLIENT_ID
flutter-dev:
	@if [ -z "$(SUPABASE_URL_LOCAL)" ] || [ -z "$(SUPABASE_ANON_KEY_LOCAL)" ]; then \
		echo "❌ Error: SUPABASE_URL_LOCAL and SUPABASE_ANON_KEY_LOCAL must be set"; \
		echo "   Set them in .env.local or export them before running"; \
		exit 1; \
	fi
	cd apps/mobile && flutter run \
		--dart-define=SUPABASE_URL=$(SUPABASE_URL_LOCAL) \
		--dart-define=SUPABASE_ANON_KEY=$(SUPABASE_ANON_KEY_LOCAL) \
		--dart-define=GOOGLE_WEB_CLIENT_ID=$(GOOGLE_WEB_CLIENT_ID) \
		--dart-define=GOOGLE_IOS_CLIENT_ID=$(GOOGLE_IOS_CLIENT_ID)

# Flutter 개발 서버 (리모트 Supabase)
# 환경변수: SUPABASE_URL_REMOTE, SUPABASE_ANON_KEY_REMOTE, GOOGLE_WEB_CLIENT_ID, GOOGLE_IOS_CLIENT_ID
flutter-dev-remote:
	@if [ -z "$(SUPABASE_URL_REMOTE)" ] || [ -z "$(SUPABASE_ANON_KEY_REMOTE)" ]; then \
		echo "❌ Error: SUPABASE_URL_REMOTE and SUPABASE_ANON_KEY_REMOTE must be set"; \
		echo "   Set them in .env.local or export them before running"; \
		exit 1; \
	fi
	cd apps/mobile && flutter run \
		--dart-define=SUPABASE_URL=$(SUPABASE_URL_REMOTE) \
		--dart-define=SUPABASE_ANON_KEY=$(SUPABASE_ANON_KEY_REMOTE) \
		--dart-define=GOOGLE_WEB_CLIENT_ID=$(GOOGLE_WEB_CLIENT_ID) \
		--dart-define=GOOGLE_IOS_CLIENT_ID=$(GOOGLE_IOS_CLIENT_ID)

# Flutter 빌드 (iOS 시뮬레이터, 로컬)
# 환경변수: SUPABASE_URL_LOCAL, SUPABASE_ANON_KEY_LOCAL, GOOGLE_WEB_CLIENT_ID, GOOGLE_IOS_CLIENT_ID
flutter-build:
	@if [ -z "$(SUPABASE_URL_LOCAL)" ] || [ -z "$(SUPABASE_ANON_KEY_LOCAL)" ]; then \
		echo "❌ Error: SUPABASE_URL_LOCAL and SUPABASE_ANON_KEY_LOCAL must be set"; \
		exit 1; \
	fi
	cd apps/mobile && flutter build ios --simulator \
		--dart-define=SUPABASE_URL=$(SUPABASE_URL_LOCAL) \
		--dart-define=SUPABASE_ANON_KEY=$(SUPABASE_ANON_KEY_LOCAL) \
		--dart-define=GOOGLE_WEB_CLIENT_ID=$(GOOGLE_WEB_CLIENT_ID) \
		--dart-define=GOOGLE_IOS_CLIENT_ID=$(GOOGLE_IOS_CLIENT_ID)

# Flutter IPA 빌드 (리모트 Supabase - TestFlight용)
# NOTE: TestFlight 배포는 항상 remote 환경 사용 (로컬 빌드 옵션 없음)
# 환경변수: SUPABASE_URL_REMOTE, SUPABASE_ANON_KEY_REMOTE, GOOGLE_WEB_CLIENT_ID, GOOGLE_IOS_CLIENT_ID
flutter-build-ipa:
	@if [ -z "$(SUPABASE_URL_REMOTE)" ] || [ -z "$(SUPABASE_ANON_KEY_REMOTE)" ]; then \
		echo "❌ Error: SUPABASE_URL_REMOTE and SUPABASE_ANON_KEY_REMOTE must be set"; \
		exit 1; \
	fi
	@echo "🚀 Building IPA for TestFlight (remote Supabase environment)..."
	cd apps/mobile && flutter build ipa \
		--dart-define=SUPABASE_URL=$(SUPABASE_URL_REMOTE) \
		--dart-define=SUPABASE_ANON_KEY=$(SUPABASE_ANON_KEY_REMOTE) \
		--dart-define=GOOGLE_WEB_CLIENT_ID=$(GOOGLE_WEB_CLIENT_ID) \
		--dart-define=GOOGLE_IOS_CLIENT_ID=$(GOOGLE_IOS_CLIENT_ID)
	@echo "✅ IPA built successfully at: apps/mobile/build/ios/ipa/"

# TestFlight 배포 (빌드 + 업로드 통합 명령)
# 사용법: make flutter-testflight
# NOTE: 항상 remote Supabase 환경 사용 (명시적 설정 불필요)
# 환경변수: APPLE_ID, APPLE_APP_PASSWORD (from ~/.zshrc)
flutter-testflight: flutter-build-ipa
	@echo "📤 Uploading to TestFlight..."
	xcrun altool --upload-app \
		--type ios \
		--file "apps/mobile/build/ios/ipa/drop_mobile.ipa" \
		-u "$(APPLE_ID)" \
		-p "$(APPLE_APP_PASSWORD)"
	@echo "✅ Upload complete! Check App Store Connect for processing status."

# Flutter 코드 분석
flutter-analyze:
	cd apps/mobile && flutter analyze

# Flutter 테스트
flutter-test:
	cd apps/mobile && flutter test

# Flutter 코드 재생성
flutter-codegen:
	cd apps/mobile && dart run build_runner build --delete-conflicting-outputs

# Flutter 정리
flutter-clean:
	cd apps/mobile && flutter clean && rm -rf .dart_tool build

# ============================================
# iOS 네이티브 (apps/ios) — Flutter 앱을 대체하는 트랙, BRU-6~22
# ============================================

# xcode-select가 CommandLineTools를 가리키고 있어 명시가 필요하다.
IOS_DEVELOPER_DIR := /Applications/Xcode.app/Contents/Developer
IOS_DIR := apps/ios
IOS_SIMULATOR ?= platform=iOS Simulator,name=iPhone 17

# project.yml → Drop.xcodeproj 생성 (.xcodeproj는 커밋하지 않는다)
ios-generate:
	@command -v xcodegen >/dev/null || { echo "❌ xcodegen이 없습니다: brew install xcodegen"; exit 1; }
	cd $(IOS_DIR) && xcodegen generate

# 도메인 로직 테스트 — 시뮬레이터 없이 돈다
ios-test:
	cd $(IOS_DIR)/Packages/DropCore && DEVELOPER_DIR=$(IOS_DEVELOPER_DIR) swift test

# 시뮬레이터용 빌드
ios-build: ios-generate
	cd $(IOS_DIR) && DEVELOPER_DIR=$(IOS_DEVELOPER_DIR) xcodebuild \
		-project Drop.xcodeproj -scheme Drop \
		-destination 'generic/platform=iOS Simulator' build

# 시뮬레이터에서 실행
ios-dev: ios-generate
	cd $(IOS_DIR) && DEVELOPER_DIR=$(IOS_DEVELOPER_DIR) xcodebuild \
		-project Drop.xcodeproj -scheme Drop \
		-destination '$(IOS_SIMULATOR)' build

# Xcode로 열기
ios-open: ios-generate
	open $(IOS_DIR)/Drop.xcodeproj

ios-clean:
	rm -rf $(IOS_DIR)/Drop.xcodeproj $(IOS_DIR)/Packages/*/.build

# ============================================
# Release — 서명·공증 DMG → GitHub Releases (설치본 자동 업데이트 채널)
# ============================================

# 표준 경로: patch 버전 범프 → 커밋 + 태그 + push → GitHub Actions가 서명·공증·발행.
# mac/iOS/Android가 한 번에 나가고, 설치본은 latest-mac.yml을 보고 자동 업데이트한다.
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
	cp -R apps/desktop/release/mac-arm64/DROP.app /Applications/
	@echo "→ /Applications/DROP.app 설치 완료"
