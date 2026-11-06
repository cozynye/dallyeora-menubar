#!/usr/bin/env bash
# .app 번들을 만들어 dist/에 dmg와 zip으로 묶는다. 사용: scripts/make-app.sh <버전>
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?버전을 지정하세요. 예: scripts/make-app.sh 0.3.0}"
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

# 열면 앱과 응용 프로그램 폴더 바로가기가 나란히 보여 끌어다 놓기만 하면 설치된다.
STAGE="dist/dmg"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
DMG="dist/Dallyeora-${VERSION}.dmg"
hdiutil create -volname "달려라 메뉴바" -srcfolder "$STAGE" -format UDZO -ov "$DMG" > /dev/null
rm -rf "$STAGE"
ZIP="dist/Dallyeora-${VERSION}.zip"
(cd dist && ditto -c -k --keepParent Dallyeora.app "Dallyeora-${VERSION}.zip")
echo "$DMG"
echo "$ZIP"
