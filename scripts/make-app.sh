#!/usr/bin/env bash
# .app 번들을 만들어 dist/에 zip으로 묶는다. 사용: scripts/make-app.sh [버전]
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-0.1.0}"
APP="dist/Dallyeora.app"

swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"

rm -rf dist
mkdir -p "$APP/Contents/MacOS"
cp "$BIN/Dallyeora" "$APP/Contents/MacOS/Dallyeora"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>com.cozynye.dallyeora</string>
    <key>CFBundleName</key><string>Dallyeora</string>
    <key>CFBundleDisplayName</key><string>달려라 메뉴바</string>
    <key>CFBundleExecutable</key><string>Dallyeora</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
(cd dist && ditto -c -k --keepParent Dallyeora.app "Dallyeora-${VERSION}.zip")
echo "dist/Dallyeora-${VERSION}.zip"
