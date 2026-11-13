#!/usr/bin/env bash
# .app 번들을 만들어 dist/에 dmg와 zip으로 묶는다. 사용: scripts/make-app.sh <버전>
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?버전을 지정하세요. 예: scripts/make-app.sh 0.3.0}"
APP="dist/Dallyeora.app"

swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"

rm -rf dist
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/Dallyeora" "$APP/Contents/MacOS/Dallyeora"
# 아이콘은 이미지 파일 없이 코드로 그려서 만든다.
"$BIN/IconTool" "$APP/Contents/Resources/AppIcon.icns" > /dev/null

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>com.cozynye.dallyeora</string>
    <key>CFBundleName</key><string>Dallyeora</string>
    <key>CFBundleDisplayName</key><string>달려라 메뉴바</string>
    <key>CFBundleExecutable</key><string>Dallyeora</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

# 키체인에 Developer ID 인증서와 notarytool 프로필(기본 이름 dallyeora)이 있으면 서명하고 공증까지 받는다.
# 없으면 ad-hoc 서명만 하고, 이 경우 받은 사람의 Gatekeeper가 처음 실행을 막는다.
NOTARY_PROFILE="${NOTARY_PROFILE:-dallyeora}"
SIGN_ID="$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -1)"
if [ -n "$SIGN_ID" ] && xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" > /dev/null 2>&1; then
    NOTARIZE=1
else
    NOTARIZE=0
    echo "Developer ID 인증서나 공증 프로필이 없어 ad-hoc 서명만 합니다." >&2
fi

if [ "$NOTARIZE" = 1 ]; then
    codesign --force --options runtime --timestamp --sign "$SIGN_ID" "$APP"
    # 앱을 먼저 공증해 티켓을 붙여 두면 zip으로 받아도 오프라인에서 검사가 통과한다.
    ditto -c -k --keepParent "$APP" dist/notarize.zip
    xcrun notarytool submit dist/notarize.zip --keychain-profile "$NOTARY_PROFILE" --wait
    rm dist/notarize.zip
    xcrun stapler staple "$APP"
else
    codesign --force --sign - "$APP"
fi

# 열면 앱과 응용 프로그램 폴더 바로가기가 나란히 보여 끌어다 놓기만 하면 설치된다.
STAGE="dist/dmg"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
DMG="dist/Dallyeora-${VERSION}.dmg"
hdiutil create -volname "달려라 메뉴바" -srcfolder "$STAGE" -format UDZO -ov "$DMG" > /dev/null
rm -rf "$STAGE"
if [ "$NOTARIZE" = 1 ]; then
    codesign --force --timestamp --sign "$SIGN_ID" "$DMG"
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG"
fi
ZIP="dist/Dallyeora-${VERSION}.zip"
(cd dist && ditto -c -k --keepParent Dallyeora.app "Dallyeora-${VERSION}.zip")
echo "$DMG"
echo "$ZIP"
