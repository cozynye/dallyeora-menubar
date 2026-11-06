# 달려라 메뉴바

macOS 메뉴 막대 앱. Swift Package (Swift 6, macOS 14+), AppKit `NSStatusItem`.

- `Sources/DallyeoraCore`: AppKit 없는 로직과 그리기. 여기에 테스트를 붙인다.
- `Sources/Dallyeora`: 메뉴 막대 UI.
- `Sources/DallyeoraCore/Processes`: 프로세스 읽기·묶기·순위·사전. 사전 항목은 `CatalogEntries.swift`에 추가하고 `ProcessCatalogTests.catalogCoversTheRequiredNames`의 목록을 함께 갱신한다.
- `Sources/Dallyeora/Cleanup`: 정리하기 창(SwiftUI를 NSHostingView로).
- `Sources/IconTool`: 빌드 때 `AppIconRenderer`(Core)로 앱 아이콘 .icns를 그리는 도구. `scripts/make-app.sh`가 부른다. 이미지 파일은 없다.
- 새 캐릭터: `Sources/DallyeoraCore/Mascots/`에 `Mascot` 구현 추가 → `Mascots.all`에 등록 → `MascotTests`의 순서 테스트 갱신.
- 그림 좌표는 28×18, y축 아래 방향, 단색.

명령: `swift test`, `swift run Dallyeora`, `scripts/make-app.sh <버전>`
설계: `docs/spec.md`, `docs/spec-cleanup.md`
