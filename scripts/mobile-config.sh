#!/usr/bin/env bash
# 환경변수로부터 apps/mobile/.config/{local,remote}.json 을 만든다
# (`flutter run --dart-define-from-file` 입력).
#
# 값 이름은 iOS(scripts/ios-config.sh)와 같다 — .env.local 을 그대로 재사용한다.
#   SUPABASE_URL_LOCAL   / SUPABASE_ANON_KEY_LOCAL
#   SUPABASE_URL_REMOTE  / SUPABASE_ANON_KEY_REMOTE
#   GOOGLE_IOS_CLIENT_ID / GOOGLE_WEB_CLIENT_ID
#
# GOOGLE_WEB_CLIENT_ID(serverClientId)는 필수다 — 빼면 Supabase가 id_token을
# `Unacceptable audience`로 거부한다 (PR #17 실증).
#
# 생성된 파일은 .gitignore 대상. 이미 있으면 덮어쓰지 않는다(손으로 고친 값 보호).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_DIR="$REPO_ROOT/apps/mobile/.config"

if [[ -f "$REPO_ROOT/.env.local" ]]; then
  # shellcheck disable=SC1091
  set -a && source "$REPO_ROOT/.env.local" && set +a
  echo "ℹ️  .env.local 을 읽었습니다"
fi

mkdir -p "$CONFIG_DIR"

write_config() {
  local name="$1" url="$2" anon_key="$3"
  local out="$CONFIG_DIR/$name.json"
  if [[ -f "$out" ]]; then
    echo "↷  $out 이미 있음 — 건너뜀"
    return
  fi
  cat > "$out" <<JSON
{
  "SUPABASE_URL": "${url}",
  "SUPABASE_ANON_KEY": "${anon_key}",
  "GOOGLE_IOS_CLIENT_ID": "${GOOGLE_IOS_CLIENT_ID:-}",
  "GOOGLE_WEB_CLIENT_ID": "${GOOGLE_WEB_CLIENT_ID:-}"
}
JSON
  echo "✓  $out"
}

write_config local "${SUPABASE_URL_LOCAL:-http://127.0.0.1:54321}" "${SUPABASE_ANON_KEY_LOCAL:-}"
write_config remote "${SUPABASE_URL_REMOTE:-}" "${SUPABASE_ANON_KEY_REMOTE:-}"

if [[ -z "${GOOGLE_WEB_CLIENT_ID:-}" ]]; then
  echo "⚠️  GOOGLE_WEB_CLIENT_ID 가 비어 있습니다 — 로그인은 audience 거부로 실패합니다"
fi
