#!/usr/bin/env bash
# DROP 아이콘 산출물 생성 — SVG 소스에서 Dock(.icns/.png)과 메뉴바 템플릿 아이콘을 만든다.
# 사용법: apps/desktop/build/logo/generate.sh   (macOS 전용 — sips/iconutil 사용, 추가 설치 불필요)
set -euo pipefail

cd "$(dirname "$0")"
BUILD_DIR=".."
APP_SVG="a-solid-drop.svg"
TRAY_SVG="tray-drop-template.svg"

echo "→ Dock 아이콘 (1024 PNG)"
sips -s format png "$APP_SVG" --out "$BUILD_DIR/icon.png" -Z 1024 >/dev/null

echo "→ .icns"
ICONSET="$(mktemp -d)/icon.iconset"
mkdir -p "$ICONSET"
for spec in "16:16x16" "32:16x16@2x" "32:32x32" "64:32x32@2x" "128:128x128" "256:128x128@2x" "256:256x256" "512:256x256@2x" "512:512x512" "1024:512x512@2x"; do
  px="${spec%%:*}"; name="${spec##*:}"
  sips -s format png "$BUILD_DIR/icon.png" --out "$ICONSET/icon_$name.png" -Z "$px" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$BUILD_DIR/icon.icns"
rm -rf "$(dirname "$ICONSET")"

echo "→ 메뉴바 템플릿 아이콘 (16 / @2x 32)"
sips -s format png "$TRAY_SVG" --out "$BUILD_DIR/trayIconTemplate.png" -Z 16 >/dev/null
sips -s format png "$TRAY_SVG" --out "$BUILD_DIR/trayIconTemplate@2x.png" -Z 32 >/dev/null

echo "완료: icon.png / icon.icns / trayIconTemplate.png / trayIconTemplate@2x.png"
