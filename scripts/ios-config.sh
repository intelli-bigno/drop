#!/usr/bin/env bash
# 환경변수로부터 apps/ios/Config/Config-*.xcconfig 를 만든다.
#
# 값은 과거 Flutter 타겟과 같은 이름을 쓴다 — 이미 .env.local에 있다면 그대로 재사용된다.
#   SUPABASE_URL_LOCAL   / SUPABASE_ANON_KEY_LOCAL
#   SUPABASE_URL_REMOTE  / SUPABASE_ANON_KEY_REMOTE
#
# 생성된 파일은 .gitignore 대상이다. 이미 있으면 덮어쓰지 않는다(손으로 고친 값 보호).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_DIR="$REPO_ROOT/apps/ios/Config"

# 레포 루트의 .env.local 이 있으면 읽어들인다.
if [[ -f "$REPO_ROOT/.env.local" ]]; then
  # shellcheck disable=SC1091
  set -a && source "$REPO_ROOT/.env.local" && set +a
  echo "ℹ️  .env.local 을 읽었습니다"
fi

# xcconfig는 `//` 부터를 주석으로 잘라낸다. 스킴 구분자 사이에 $() 를 끼워
# 빌드 시 빈 문자열로 치환되게 하는 것이 표준 우회다.
escape_url() {
  printf '%s' "$1" | sed 's|://|:/$()/|'
}

# Google 로그인 콜백 URL 스킴은 iOS 클라이언트 ID를 뒤집은 값이다.
#   123-abc.apps.googleusercontent.com  →  com.googleusercontent.apps.123-abc
reversed_client_id() {
  local id="$1"
  [[ -z "$id" ]] && return 0
  printf 'com.googleusercontent.apps.%s' "${id%%.apps.googleusercontent.com}"
}

write_config() {
  local env_name="$1" url="$2" key="$3" out="$4"

  if [[ -f "$out" ]]; then
    echo "⏭️  $(basename "$out") 이미 있음 — 건너뜁니다"
    return 0
  fi

  if [[ -z "$url" || -z "$key" ]]; then
    echo "⚠️  $(basename "$out") 생성 안 함 — 필요한 환경변수가 비어 있습니다"
    return 0
  fi

  cat > "$out" <<EOF
// make ios-config 로 생성됨. 커밋되지 않는 파일입니다.
DROP_ENVIRONMENT = $env_name

SUPABASE_URL = $(escape_url "$url")
SUPABASE_ANON_KEY = $key

// serverClientId 에는 반드시 **웹** 클라이언트 ID를 넣는다.
// iOS 것을 넣으면 id_token 의 audience 가 어긋나 Supabase 가 거부한다.
GOOGLE_WEB_CLIENT_ID = ${GOOGLE_WEB_CLIENT_ID:-}
GOOGLE_IOS_CLIENT_ID = ${GOOGLE_IOS_CLIENT_ID:-}
GOOGLE_IOS_CLIENT_ID_REVERSED = $(reversed_client_id "${GOOGLE_IOS_CLIENT_ID:-}")
EOF
  echo "✅ $(basename "$out") 생성"

  if [[ -z "${GOOGLE_WEB_CLIENT_ID:-}" || -z "${GOOGLE_IOS_CLIENT_ID:-}" ]]; then
    echo "   ⚠️  GOOGLE_WEB_CLIENT_ID / GOOGLE_IOS_CLIENT_ID 가 비어 있습니다 — 로그인은 실행 시점에 실패합니다"
  fi
}

mkdir -p "$CONFIG_DIR"

write_config localdev \
  "${SUPABASE_URL_LOCAL:-http://127.0.0.1:58321}" \
  "${SUPABASE_ANON_KEY_LOCAL:-}" \
  "$CONFIG_DIR/Config-localdev.xcconfig"

write_config remote \
  "${SUPABASE_URL_REMOTE:-}" \
  "${SUPABASE_ANON_KEY_REMOTE:-}" \
  "$CONFIG_DIR/Config-remote.xcconfig"

echo
echo "값을 직접 넣으려면 .example 파일을 복사해 쓰세요:"
echo "  cp apps/ios/Config/Config-localdev.xcconfig.example apps/ios/Config/Config-localdev.xcconfig"
