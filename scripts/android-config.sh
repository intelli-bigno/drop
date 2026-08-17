#!/usr/bin/env bash
# 환경변수로부터 apps/android/local.properties 를 만든다.
#
# iOS의 scripts/ios-config.sh 와 같은 자리다. 값이 흐르는 경로:
#   .env.local / export한 환경변수
#     → 이 스크립트
#     → apps/android/local.properties        (gitignore)
#     → app/build.gradle.kts 가 BuildConfig 로 굽는다
#     → BuildConfig.SUPABASE_URL / SUPABASE_ANON_KEY
#
# 값 이름은 iOS 타겟과 같다 — 기존 .env.local 을 그대로 재사용한다.
#   SUPABASE_URL_LOCAL / SUPABASE_ANON_KEY_LOCAL
#   SUPABASE_URL_REMOTE / SUPABASE_ANON_KEY_REMOTE
#
# 사용법:
#   scripts/android-config.sh            # local 환경 (기본)
#   scripts/android-config.sh remote     # remote 환경
set -euo pipefail

ENVIRONMENT="${1:-local}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$REPO_ROOT/apps/android/local.properties"

if [[ -f "$REPO_ROOT/.env.local" ]]; then
  # shellcheck disable=SC1091
  set -a && source "$REPO_ROOT/.env.local" && set +a
  echo "ℹ️  .env.local 을 읽었습니다"
fi

case "$ENVIRONMENT" in
  local)
    URL="${SUPABASE_URL_LOCAL:-http://10.0.2.2:58321}"   # 에뮬레이터에서 본 호스트의 localhost
    KEY="${SUPABASE_ANON_KEY_LOCAL:-}"
    ;;
  remote)
    URL="${SUPABASE_URL_REMOTE:-}"
    KEY="${SUPABASE_ANON_KEY_REMOTE:-}"
    ;;
  *)
    echo "❌ 알 수 없는 환경: $ENVIRONMENT (local | remote)"
    exit 1
    ;;
esac

# Google 로그인의 serverClientId. **웹** 클라이언트 ID여야 한다 — Supabase Google
# provider가 audience로 신뢰하는 것이 웹 클라이언트 하나뿐이라, Android 클라이언트 ID를
# 넣으면 `Unacceptable audience`로 거부된다.
#
# 기본값을 박아 두는 이유: OAuth 클라이언트 ID는 비밀값이 아니다(APK 안에 그대로 실린다).
# .env.local 이 없는 기계에서도 로그인 빌드가 되게 하려고 실제 값을 기본으로 둔다.
GOOGLE_WEB_CLIENT_ID="${GOOGLE_WEB_CLIENT_ID:-627053596385-pn1ba7kvg7rcfhesr532qtdc19vnqf5m.apps.googleusercontent.com}"

# SDK 경로. ANDROID_HOME 이 있으면 그것을, 없으면 macOS 기본 위치를 쓴다.
SDK_DIR="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"

{
  echo "# scripts/android-config.sh 로 생성됨 (환경: $ENVIRONMENT). 커밋되지 않는 파일입니다."
  [[ -d "$SDK_DIR" ]] && echo "sdk.dir=$SDK_DIR"
  echo "SUPABASE_URL=$URL"
  echo "SUPABASE_ANON_KEY=$KEY"
  echo "GOOGLE_WEB_CLIENT_ID=$GOOGLE_WEB_CLIENT_ID"
} > "$OUT"

echo "✅ apps/android/local.properties 생성 (환경: $ENVIRONMENT)"

if [[ -z "$KEY" ]]; then
  echo "   ⚠️  SUPABASE_ANON_KEY 가 비어 있습니다 — 네트워크 호출은 실행 시점에 실패합니다"
fi
if [[ ! -d "$SDK_DIR" ]]; then
  echo "   ⚠️  Android SDK 를 찾지 못했습니다($SDK_DIR) — ANDROID_HOME 을 지정하세요"
fi
