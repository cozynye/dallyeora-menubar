#!/bin/sh
# 달려라 메뉴바 한 줄 설치.
# 최신 Release의 zip을 받아 응용 프로그램 폴더에 넣고 실행한다.
# curl로 받은 파일에는 macOS 격리 표시가 붙지 않아 "확인할 수 없습니다" 경고 없이 열린다.
# 테스트용: DALLYEORA_ZIP=경로 를 주면 내려받지 않고 그 zip을 설치한다.
set -eu

REPO="cozynye/dallyeora-menubar"
APP_NAME="Dallyeora.app"
DEST="/Applications"
if [ ! -w "$DEST" ]; then
  DEST="$HOME/Applications"
  mkdir -p "$DEST"
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

if [ -n "${DALLYEORA_ZIP:-}" ]; then
  cp "$DALLYEORA_ZIP" "$TMP/app.zip"
else
  echo "최신 버전을 확인합니다..."
  URL=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
    | grep '"browser_download_url"' | grep '\.zip"' | head -1 | sed 's/.*"\(https[^"]*\)".*/\1/')
  if [ -z "$URL" ]; then
    echo "다운로드 주소를 찾지 못했습니다. https://github.com/$REPO/releases 에서 직접 받아 주세요." >&2
    exit 1
  fi
  echo "내려받는 중: $URL"
  curl -fsSL "$URL" -o "$TMP/app.zip"
fi

ditto -x -k "$TMP/app.zip" "$TMP"
if [ ! -d "$TMP/$APP_NAME" ]; then
  echo "zip 안에 $APP_NAME 이 없습니다." >&2
  exit 1
fi

if pgrep -x Dallyeora >/dev/null 2>&1; then
  echo "실행 중인 앱을 끕니다."
  pkill -x Dallyeora || true
  sleep 1
fi

rm -rf "$DEST/$APP_NAME"
ditto "$TMP/$APP_NAME" "$DEST/$APP_NAME"
xattr -dr com.apple.quarantine "$DEST/$APP_NAME" 2>/dev/null || true
open "$DEST/$APP_NAME"
echo "설치했습니다: $DEST/$APP_NAME"
echo "메뉴 막대 오른쪽 위에 개복치가 보이면 끝입니다."
