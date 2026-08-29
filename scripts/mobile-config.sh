#!/usr/bin/env bash
# 환경변수로부터 아래 두 가지를 만든다.
#   1. apps/mobile/.config/{local,remote}.json  (`--dart-define-from-file` 입력)
#   2. apps/mobile/ios/Flutter/GoogleSignIn.xcconfig  (Info.plist 의 URL 스킴)
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

# --- iOS Google 로그인 콜백 URL 스킴 (BRU-186) ---------------------------------
#
# GIDSignIn 은 시작할 때 앱 번들에 **역방향 클라이언트 ID** URL 스킴이 등록돼
# 있는지 보고, 없으면 NSException 을 던져 앱을 죽인다. dart-define 으로 넘기는
# clientId 만으로는 부족하다 — Info.plist 에 실제로 박혀 있어야 한다.
#   123-abc.apps.googleusercontent.com  →  com.googleusercontent.apps.123-abc
#
# 값 자체는 비밀이 아니지만(배포 바이너리 전부에 들어간다) 생성물은 커밋하지
# 않는다. 순수 파생물이라 .config/*.json 과 달리 **항상 덮어쓴다** — 손으로 고칠
# 파일이 아니고, 낡은 값이 남으면 크래시가 조용히 되살아난다.
reversed_client_id() {
  local id="$1"
  [[ -z "$id" ]] && return 0
  printf 'com.googleusercontent.apps.%s' "${id%%.apps.googleusercontent.com}"
}

# 환경변수가 비어 있어도, 이미 만들어진 .config 가 있으면 그쪽 값을 쓴다.
# 앱이 실제로 dart-define 으로 받는 값과 Info.plist 의 스킴이 갈리면 안 된다.
IOS_CLIENT_ID="${GOOGLE_IOS_CLIENT_ID:-}"
if [[ -z "$IOS_CLIENT_ID" ]]; then
  for existing in "$CONFIG_DIR/remote.json" "$CONFIG_DIR/local.json"; do
    [[ -f "$existing" ]] || continue
    IOS_CLIENT_ID="$(sed -n 's/.*"GOOGLE_IOS_CLIENT_ID"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$existing")"
    [[ -n "$IOS_CLIENT_ID" ]] && break
  done
fi

GOOGLE_XCCONFIG="$REPO_ROOT/apps/mobile/ios/Flutter/GoogleSignIn.xcconfig"
cat > "$GOOGLE_XCCONFIG" <<XCCONFIG
// make mobile-config 로 생성됨. 커밋되지 않는 파일입니다 (BRU-186).
// Runner/Info.plist 의 CFBundleURLTypes 가 이 값을 참조한다.
GOOGLE_IOS_CLIENT_ID_REVERSED = $(reversed_client_id "$IOS_CLIENT_ID")
XCCONFIG
echo "✓  $GOOGLE_XCCONFIG"

if [[ -z "$IOS_CLIENT_ID" ]]; then
  echo "⚠️  GOOGLE_IOS_CLIENT_ID 가 비어 있습니다 — iOS Google 로그인은 버튼을 누르는 순간 크래시합니다"
fi

if [[ -z "${GOOGLE_WEB_CLIENT_ID:-}" ]]; then
  echo "⚠️  GOOGLE_WEB_CLIENT_ID 가 비어 있습니다 — 로그인은 audience 거부로 실패합니다"
fi
