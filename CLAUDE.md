# 달려라 메뉴바

macOS 메뉴 막대 앱. Swift Package (Swift 6, macOS 14+), AppKit `NSStatusItem`.

- `Sources/DallyeoraCore`: AppKit 없는 로직과 그리기. 여기에 테스트를 붙인다.
- `Sources/Dallyeora`: 메뉴 막대 UI.
- 새 캐릭터: `Sources/DallyeoraCore/Mascots/`에 `Mascot` 구현 추가 → `Mascots.all`에 등록 → `MascotTests`의 순서 테스트 갱신.
- 그림 좌표는 28×18, y축 아래 방향, 단색.

명령: `swift test`, `swift run Dallyeora`, `scripts/make-app.sh <버전>`
설계: `docs/spec.md`
