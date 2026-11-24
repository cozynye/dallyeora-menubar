# 달려라 메뉴바

macOS 메뉴 막대 앱. Swift Package (Swift 6, macOS 14+), AppKit `NSStatusItem`.

- `Sources/DallyeoraCore`: AppKit 없는 로직과 그리기. 여기에 테스트를 붙인다.
- `Sources/Dallyeora`: 메뉴 막대 UI. `StatusItemController`는 재기와 그리기, `StatusMenu`는 메뉴를 맡는다. 메뉴 액션은 `Settings`만 바꾸고, 다시 그리기는 `Settings.didChange`를 듣는 쪽이 한다. `LoginItem`(SMAppService), `ActivityMonitor`(화면 꺼짐), `GlobalHotKey`(⌃⌥⌘D), `UpdateChecker`(하루 한 번 GitHub 최신 릴리스 번호 확인, 판단은 `DallyeoraCore/Update`)는 얇은 감싸기다.
- `Sources/DallyeoraCore/Processes`: 프로세스 읽기·묶기·순위·사전. 사전 항목은 `CatalogEntries.swift`에 추가하고 `ProcessCatalogTests.catalogCoversTheRequiredNames`의 목록을 함께 갱신한다.
- `Sources/Dallyeora/Cleanup`: 정리하기 창(SwiftUI를 NSHostingView로).
- `Sources/DallyeoraCore/Cleanup`: 정리하기 창의 검색(`RowFilter`), 줄 고정(`StableOrder`), 상태 줄 문구(`CleanupNotice`), 앱 종료 흐름(`QuitTracker`), 창 갱신 조건(`CleanupRunState`). 문구를 바꾸면 `docs/spec-usability.md` 3.5의 표도 함께 고친다.
- `Sources/IconTool`: 빌드 때 `AppIconRenderer`(Core)로 앱 아이콘 .icns를 그리는 도구. `scripts/make-app.sh`가 부른다. 이미지 파일은 없다.
- 새 캐릭터: `Sources/DallyeoraCore/Mascots/`에 `Mascot` 구현 추가 → `Mascots.all`에 등록 → `MascotTests`의 순서 테스트 갱신.
- 그림 좌표는 28×18, y축 아래 방향, 단색.
- 상태(타이머, 플래그, 단계 전이)를 건드리기 전에 `docs/state-machines.md`에서 해당 머신을 확인한다. 전이 규칙은 Core의 struct에 두고 테스트를 붙이며, 앱 쪽에는 타이머와 AppKit 호출만 남긴다. 상태나 전이를 바꾸면 그 문서도 함께 고친다.

명령: `swift test`, `swift run Dallyeora`, `scripts/make-app.sh <버전>`
설계: `docs/spec.md`, `docs/spec-cleanup.md`, `docs/spec-usability.md`, `docs/state-machines.md`
