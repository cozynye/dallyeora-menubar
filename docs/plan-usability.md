# 사용성 정리 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 로그인 시 실행, 메뉴 막대 사용률 표시, 화면이 꺼지면 멈춤, 정리하기 창의 검색·줄 고정·종료 확인·결과 표시·지표 공유·전역 단축키를 넣고 `StatusItemController`를 나눈다.

**Architecture:** 판단과 문구는 `DallyeoraCore`의 순수 타입(`StatusTitle`, `ActivityState`, `RowFilter`, `StableOrder`, `CleanupNotice`, `SignalResult`)에 두고 테스트한다. `Settings`가 값이 바뀔 때 알림을 한 번 보내고, 메뉴 막대 컨트롤러와 정리하기 모델이 그 알림 하나로 다시 그린다. AppKit에 붙는 부분(`StatusMenu`, `LoginItem`, `ActivityMonitor`, `GlobalHotKey`)은 얇은 감싸기로 둔다.

**Tech Stack:** Swift 6 (strict concurrency), Swift Package, macOS 14+, AppKit, SwiftUI(창 내용만), Observation, ServiceManagement, Carbon(HIToolbox), Swift Testing.

**Spec:** `docs/spec-usability.md`

## Global Constraints

- Swift tools 6.0, `platforms: [.macOS(.v14)]`, strict concurrency. 경고 없이 빌드되어야 한다.
- Core 타깃(`Sources/DallyeoraCore`)은 AppKit·SwiftUI를 import하지 않는다.
- 사설 API 금지. 접근성·화면 녹화 권한을 요구하는 API 금지.
- 사용자에게 보이는 문구는 모두 한국어이고 스펙 3.5의 표를 글자 그대로 쓴다.
- 전역 단축키는 ⌃⌥⌘D 고정, 상태 줄은 5초, 대사 폭 상한 150pt는 그대로다.
- 커밋과 push는 사용자가 요청할 때만 한다. 커밋 메시지에 클로드 표시를 넣지 않는다.
- README는 고친 뒤 커밋하지 않고 diff를 사용자에게 보여 준다.
- 테스트 뒤 `defaults delete com.cozynye.dallyeora.tests`로 정리한다.

## Review Focus

1. 한글 검색어가 자모 분리(NFD)로 들어와도 완성형 제목과 맞아야 한다. (Task 4 `matchesDecomposedHangul`)
2. 같은 값을 다시 써도 알림이 가면 창과 메뉴가 서로를 깨우며 돈다. 값이 실제로 바뀔 때만 알린다. (Task 1 `sameValueDoesNotNotify`)
3. 화면은 깨어났는데 세션이 아직 비활성이면 계속 멈춰 있어야 한다. (Task 3 `staysPausedUntilBothClear`)
4. 줄을 고정한 동안 줄이 사라졌다가 새 줄이 생겨도 남은 줄의 순서는 그대로여야 한다. (Task 4 `keepsFrozenOrderAndAppendsNew`)
5. 사용률이 NaN이나 범위 밖이어도 메뉴 막대 글자를 만들다 죽지 않는다. (Task 2 `clampsOddPercents`)

---

### Task 1: Settings에 사용률 표시와 변경 알림

**Files:**
- Modify: `Sources/DallyeoraCore/Settings.swift`
- Test: `Tests/DallyeoraCoreTests/SettingsTests.swift`

**Interfaces:**
- Produces: `Settings.showsPercent: Bool`(기본 false), `Settings.Key.showsPercent`, `Settings.didChange: Notification.Name`(object는 그 `Settings`, 값이 실제로 바뀔 때만 보냄)

- [ ] **Step 1: 실패하는 테스트.** `SettingsTests`에 추가한다.

```swift
    @Test func showsPercentDefaultsOffAndPersists() {
        let s = Settings(defaults: defaults)
        #expect(s.showsPercent == false)
        s.showsPercent = true
        #expect(Settings(defaults: defaults).showsPercent == true)
    }

    @Test func notifiesOncePerRealChange() {
        let s = Settings(defaults: defaults)
        let count = Counter()
        let token = NotificationCenter.default.addObserver(forName: Settings.didChange, object: s, queue: nil) { _ in
            count.value += 1
        }
        defer { NotificationCenter.default.removeObserver(token) }
        s.metric = .memory
        s.tone = .gyeongsang
        s.mascotID = "pork"
        s.showsPhrase = true
        s.showsPercent = true
        #expect(count.value == 5)
    }

    @Test func sameValueDoesNotNotify() {
        let s = Settings(defaults: defaults)
        s.metric = .memory
        let count = Counter()
        let token = NotificationCenter.default.addObserver(forName: Settings.didChange, object: s, queue: nil) { _ in
            count.value += 1
        }
        defer { NotificationCenter.default.removeObserver(token) }
        s.metric = .memory
        s.showsPhrase = false
        #expect(count.value == 0, "같은 값을 다시 쓰면 창과 메뉴가 서로를 깨우지 않는다")
    }
```

파일 끝에 `private final class Counter: @unchecked Sendable { var value = 0 }`를 둔다.

- [ ] **Step 2:** `swift test --filter SettingsTests` → `showsPercent`, `didChange`가 없어 컴파일 실패.

- [ ] **Step 3: 구현.** 각 setter를 `guard newValue != 현재값 else { return }` → 저장 → `changed()`로 바꾸고 아래를 추가한다.

```swift
    /// 값이 실제로 바뀌었을 때 보낸다. object는 이 Settings.
    public static let didChange = Notification.Name("com.cozynye.dallyeora.settingsDidChange")

    /// 메뉴 막대에 아이콘 옆 사용률 숫자를 붙일지. 기본은 끔.
    public var showsPercent: Bool {
        get { defaults.bool(forKey: Key.showsPercent) }
        set {
            guard newValue != showsPercent else { return }
            defaults.set(newValue, forKey: Key.showsPercent)
            changed()
        }
    }

    private func changed() {
        NotificationCenter.default.post(name: Self.didChange, object: self)
    }
```

- [ ] **Step 4:** `swift test --filter SettingsTests` → 통과.

### Task 2: 메뉴 막대 글자와 폭 (StatusTitle, StatusLayout)

**Files:**
- Create: `Sources/DallyeoraCore/StatusTitle.swift`
- Modify: `Sources/DallyeoraCore/StatusLayout.swift`
- Test: `Tests/DallyeoraCoreTests/StatusTitleTests.swift`, `Tests/DallyeoraCoreTests/StatusLayoutTests.swift`

**Interfaces:**
- Produces: `StatusTitle.text(percent: Double?, phrase: String?) -> String`, `StatusTitle.widestPercent`(`" 100%"`), `StatusLayout.length(iconWidth:percentWidth:phraseWidths:)`(`percentWidth` 기본 0)

- [ ] **Step 1: 실패하는 테스트.**

```swift
import Testing
@testable import DallyeoraCore

struct StatusTitleTests {
    @Test func fourCombinations() {
        #expect(StatusTitle.text(percent: nil, phrase: nil) == "")
        #expect(StatusTitle.text(percent: 42.4, phrase: nil) == " 42%")
        #expect(StatusTitle.text(percent: nil, phrase: "스트레스로 위독") == " 스트레스로 위독")
        #expect(StatusTitle.text(percent: 42.4, phrase: "스트레스로 위독") == " 42% 스트레스로 위독")
    }

    @Test func clampsOddPercents() {
        #expect(StatusTitle.text(percent: .nan, phrase: nil) == " 0%")
        #expect(StatusTitle.text(percent: -5, phrase: nil) == " 0%")
        #expect(StatusTitle.text(percent: 250, phrase: nil) == " 100%")
    }

    @Test func widestPercentIsTheHundred() {
        #expect(StatusTitle.widestPercent == StatusTitle.text(percent: 100, phrase: nil))
    }
}
```

`StatusLayoutTests`에 추가:

```swift
    @Test func addsPercentWidthOutsideThePhraseCap() {
        #expect(StatusLayout.length(iconWidth: 28, percentWidth: 34, phraseWidths: [300])
            == 28 + 34 + StatusLayout.maxPhraseWidth + StatusLayout.padding)
        #expect(StatusLayout.length(iconWidth: 28, percentWidth: 34, phraseWidths: []) == 28 + 34 + StatusLayout.padding)
    }
```

- [ ] **Step 2:** `swift test --filter Status` → 컴파일 실패.

- [ ] **Step 3: 구현.**

```swift
/// 메뉴 막대 아이콘 옆 글자. 사용률과 대사를 각각 붙이거나 뺀다.
public enum StatusTitle {
    /// 폭을 고정할 때 기준으로 삼는 가장 긴 숫자.
    public static let widestPercent = " 100%"

    public static func text(percent: Double?, phrase: String?) -> String {
        var text = ""
        if let percent { text += " " + UsageFormat.percent(percent) }
        if let phrase { text += " " + phrase }
        return text
    }
}
```

```swift
    public static func length(iconWidth: CGFloat, percentWidth: CGFloat = 0, phraseWidths: [CGFloat]) -> CGFloat {
        iconWidth + percentWidth + min(phraseWidths.max() ?? 0, maxPhraseWidth) + padding
    }
```

- [ ] **Step 4:** `swift test --filter Status` → 통과.

### Task 3: ActivityState

**Files:**
- Create: `Sources/DallyeoraCore/ActivityState.swift`
- Test: `Tests/DallyeoraCoreTests/ActivityStateTests.swift`

**Interfaces:**
- Produces: `ActivityState`(`init()`, `isActive: Bool`, `mutating handle(_ event: Event) -> Bool`), `ActivityState.Event`(`.screensDidSleep`, `.screensDidWake`, `.sessionDidResignActive`, `.sessionDidBecomeActive`). `handle`은 `isActive`가 바뀌었을 때만 true.

- [ ] **Step 1: 실패하는 테스트.**

```swift
import Testing
@testable import DallyeoraCore

struct ActivityStateTests {
    @Test func startsActive() {
        #expect(ActivityState().isActive)
    }

    @Test func sleepPausesAndWakeResumes() {
        var state = ActivityState()
        #expect(state.handle(.screensDidSleep) == true)
        #expect(state.isActive == false)
        #expect(state.handle(.screensDidSleep) == false, "같은 알림이 두 번 와도 한 번만 바뀐다")
        #expect(state.handle(.screensDidWake) == true)
        #expect(state.isActive)
    }

    @Test func staysPausedUntilBothClear() {
        var state = ActivityState()
        _ = state.handle(.sessionDidResignActive)
        #expect(state.handle(.screensDidSleep) == false)
        #expect(state.handle(.screensDidWake) == false, "세션이 아직 비활성이면 깨어나도 멈춰 있다")
        #expect(state.isActive == false)
        #expect(state.handle(.sessionDidBecomeActive) == true)
        #expect(state.isActive)
    }
}
```

- [ ] **Step 2:** `swift test --filter ActivityStateTests` → 컴파일 실패.

- [ ] **Step 3: 구현.**

```swift
/// 화면이 잠들었거나 다른 사용자로 전환된 동안에는 그릴 필요가 없다. 두 조건이 모두 풀려야 다시 돈다.
public struct ActivityState: Equatable, Sendable {
    public enum Event: Sendable {
        case screensDidSleep, screensDidWake, sessionDidResignActive, sessionDidBecomeActive
    }

    private var screensAsleep = false
    private var sessionInactive = false

    public init() {}

    public var isActive: Bool { !screensAsleep && !sessionInactive }

    /// 알림을 반영하고, 돌아야 하는지가 바뀌었으면 true.
    public mutating func handle(_ event: Event) -> Bool {
        let before = isActive
        switch event {
        case .screensDidSleep: screensAsleep = true
        case .screensDidWake: screensAsleep = false
        case .sessionDidResignActive: sessionInactive = true
        case .sessionDidBecomeActive: sessionInactive = false
        }
        return isActive != before
    }
}
```

- [ ] **Step 4:** `swift test --filter ActivityStateTests` → 통과.

### Task 4: 정리하기 창의 순수 로직 (RowFilter, StableOrder, CleanupNotice, SignalResult)

**Files:**
- Create: `Sources/DallyeoraCore/Cleanup/RowFilter.swift`, `StableOrder.swift`, `CleanupNotice.swift`, `SignalResult.swift`
- Test: `Tests/DallyeoraCoreTests/CleanupLogicTests.swift`

**Interfaces:**
- Produces:
  - `RowFilter.matches(query: String, in fields: [String]) -> Bool`
  - `StableOrder.arrange<ID: Hashable>(_ ranked: [ID], keeping frozen: [ID]?) -> [ID]`
  - `SignalResult`(`.sent`, `.notPermitted`, `.noSuchProcess`, `.failed`), `SignalResult(killResult: Int32, errno: Int32)`
  - `CleanupNotice`(아래 case), `.text: String`, `CleanupNotice.duration`(5)

- [ ] **Step 1: 실패하는 테스트.**

```swift
import Darwin
import Testing
@testable import DallyeoraCore

struct RowFilterTests {
    @Test func emptyQueryMatchesEverything() {
        #expect(RowFilter.matches(query: "", in: ["Slack"]))
        #expect(RowFilter.matches(query: "   ", in: []))
    }

    @Test func ignoresCaseAndSurroundingSpace() {
        #expect(RowFilter.matches(query: "  chro ", in: ["Google Chrome", "웹 브라우저"]))
        #expect(RowFilter.matches(query: "브라우저", in: ["Google Chrome", "웹 브라우저"]))
        #expect(RowFilter.matches(query: "slack", in: ["Google Chrome", "웹 브라우저"]) == false)
    }

    @Test func matchesMemberNames() {
        #expect(RowFilter.matches(query: "renderer", in: ["Google Chrome", "웹 브라우저", "Google Chrome Helper (Renderer)"]))
    }

    @Test func matchesDecomposedHangul() {
        let decomposed = "카카오".decomposedStringWithCanonicalMapping
        #expect(decomposed.unicodeScalars.count > 3)
        #expect(RowFilter.matches(query: decomposed, in: ["카카오톡"]))
    }
}

struct StableOrderTests {
    @Test func noFrozenOrderMeansRankedOrder() {
        #expect(StableOrder.arrange(["b", "a", "c"], keeping: nil) == ["b", "a", "c"])
    }

    @Test func keepsFrozenOrderAndAppendsNew() {
        let frozen = ["a", "b", "c"]
        #expect(StableOrder.arrange(["c", "b", "a"], keeping: frozen) == ["a", "b", "c"])
        #expect(StableOrder.arrange(["x", "c", "a", "y"], keeping: frozen) == ["a", "c", "x", "y"],
                "사라진 b는 빠지고 새 줄은 사용량 순으로 아래에 붙는다")
    }

    @Test func worksForPIDs() {
        #expect(StableOrder.arrange([Int32(30), 10, 20], keeping: [10, 20]) == [10, 20, 30])
    }
}

struct CleanupNoticeTests {
    @Test func appTexts() {
        #expect(CleanupNotice.quit(app: "Slack").text == "종료했습니다: Slack")
        #expect(CleanupNotice.quitNotSent(app: "Slack").text == "종료 요청을 보내지 못했습니다: Slack")
        #expect(CleanupNotice.unresponsive(app: "Slack").text == "응답이 없어 강제 종료 버튼으로 바꿨습니다: Slack")
        #expect(CleanupNotice.forceQuit(app: "Slack").text == "강제 종료했습니다: Slack")
        #expect(CleanupNotice.forceQuitFailed(app: "Slack").text == "강제 종료하지 못했습니다: Slack")
    }

    @Test func processTexts() {
        #expect(CleanupNotice.processEnded(name: "node", pid: 12).text == "종료했습니다: node (pid 12)")
        #expect(CleanupNotice.processStillRunning(name: "node", pid: 12).text == "종료를 요청했지만 아직 실행 중입니다: node (pid 12)")
        #expect(CleanupNotice.processNotPermitted(name: "node", pid: 12).text == "권한이 없어 끌 수 없습니다: node (pid 12)")
        #expect(CleanupNotice.processAlreadyGone(name: "node", pid: 12).text == "이미 끝난 프로세스입니다: node (pid 12)")
        #expect(CleanupNotice.processFailed(name: "node", pid: 12).text == "끌 수 없습니다: node (pid 12)")
    }

    @Test func staysForFiveSeconds() {
        #expect(CleanupNotice.duration == 5)
    }
}

struct SignalResultTests {
    @Test func mapsKillResults() {
        #expect(SignalResult(killResult: 0, errno: 0) == .sent)
        #expect(SignalResult(killResult: -1, errno: EPERM) == .notPermitted)
        #expect(SignalResult(killResult: -1, errno: ESRCH) == .noSuchProcess)
        #expect(SignalResult(killResult: -1, errno: EINVAL) == .failed)
    }
}
```

- [ ] **Step 2:** `swift test --filter "RowFilterTests|StableOrderTests|CleanupNoticeTests|SignalResultTests"` → 컴파일 실패.

- [ ] **Step 3: 구현.**

```swift
import Foundation

/// 정리하기 창의 검색. 줄의 제목·설명·프로세스 이름 중 하나에 검색어가 들어 있으면 맞다.
public enum RowFilter {
    public static func matches(query: String, in fields: [String]) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).precomposedStringWithCanonicalMapping
        guard !needle.isEmpty else { return true }
        return fields.contains {
            $0.precomposedStringWithCanonicalMapping.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }
}
```

```swift
/// 마우스가 목록 위에 있는 동안 줄이 움직이지 않게 순서를 붙잡는다.
public enum StableOrder {
    /// `frozen`에 있던 것은 그 순서대로 두고, 새로 생긴 것은 `ranked` 순서로 뒤에 붙인다. 사라진 것은 뺀다.
    public static func arrange<ID: Hashable>(_ ranked: [ID], keeping frozen: [ID]?) -> [ID] {
        guard let frozen else { return ranked }
        let live = Set(ranked)
        let kept = frozen.filter(live.contains)
        let keptSet = Set(kept)
        return kept + ranked.filter { !keptSet.contains($0) }
    }
}
```

```swift
import Darwin

/// `kill`의 결과. 실패 이유에 따라 상태 줄 문구가 달라진다.
public enum SignalResult: Equatable, Sendable {
    case sent, notPermitted, noSuchProcess, failed

    public init(killResult: Int32, errno code: Int32) {
        if killResult == 0 {
            self = .sent
        } else {
            switch code {
            case EPERM: self = .notPermitted
            case ESRCH: self = .noSuchProcess
            default: self = .failed
            }
        }
    }
}
```

```swift
import Foundation

/// 정리하기 창 아래 상태 줄에 잠깐 보여 주는 결과.
public enum CleanupNotice: Equatable, Sendable {
    case quit(app: String)
    case quitNotSent(app: String)
    case unresponsive(app: String)
    case forceQuit(app: String)
    case forceQuitFailed(app: String)
    case processEnded(name: String, pid: Int32)
    case processStillRunning(name: String, pid: Int32)
    case processNotPermitted(name: String, pid: Int32)
    case processAlreadyGone(name: String, pid: Int32)
    case processFailed(name: String, pid: Int32)

    /// 상태 줄에 머무는 시간(초).
    public static let duration: TimeInterval = 5

    public var text: String {
        switch self {
        case .quit(let app): "종료했습니다: \(app)"
        case .quitNotSent(let app): "종료 요청을 보내지 못했습니다: \(app)"
        case .unresponsive(let app): "응답이 없어 강제 종료 버튼으로 바꿨습니다: \(app)"
        case .forceQuit(let app): "강제 종료했습니다: \(app)"
        case .forceQuitFailed(let app): "강제 종료하지 못했습니다: \(app)"
        case .processEnded(let name, let pid): "종료했습니다: \(name) (pid \(pid))"
        case .processStillRunning(let name, let pid): "종료를 요청했지만 아직 실행 중입니다: \(name) (pid \(pid))"
        case .processNotPermitted(let name, let pid): "권한이 없어 끌 수 없습니다: \(name) (pid \(pid))"
        case .processAlreadyGone(let name, let pid): "이미 끝난 프로세스입니다: \(name) (pid \(pid))"
        case .processFailed(let name, let pid): "끌 수 없습니다: \(name) (pid \(pid))"
        }
    }
}
```

- [ ] **Step 4:** 같은 필터로 `swift test` → 통과.

### Task 5: StatusItemController 분리, 사용률 표시

**Files:**
- Create: `Sources/Dallyeora/StatusMenu.swift`
- Modify: `Sources/Dallyeora/StatusItemController.swift`

**Interfaces:**
- Consumes: `Settings.didChange`, `Settings.showsPercent`, `StatusTitle`, `StatusLayout.length(iconWidth:percentWidth:phraseWidths:)`
- Produces: `StatusMenu(settings:)`, `.menu: NSMenu`, `.onOpen`, `.onCleanup`, `.setHeader(_:phrase:)`, `.refreshChecks()`, `.setCleanupShortcutVisible(_:)`. `StatusItemController.apply()`.

- [ ] **Step 1:** `StatusMenu`를 만든다. 지금 `buildMenu`, `updateChecks`, `select*`, `togglePhrase`를 옮기되 액션은 설정만 바꾼다(다시 그리기는 알림이 한다). 항목 순서는 스펙 3.1이고 "메뉴 막대에 사용률 표시"를 대사 표시 아래에 넣는다. `menuWillOpen`은 `refreshChecks()` 뒤 `onOpen?()`을 부른다. "정리하기…"는 `onCleanup?()`을 부른다. `setCleanupShortcutVisible(true)`면 `keyEquivalent = "d"`, `keyEquivalentModifierMask = [.control, .option, .command]`, false면 비운다.
- [ ] **Step 2:** `StatusItemController`에서 메뉴 코드를 지우고 `StatusMenu`를 쓴다. `init`에서 `Settings.didChange`(object: settings, queue: nil)를 듣고 `apply()`를 부른다.

```swift
    /// 설정이 바뀌면 체크 표시, 폭, 그림을 한 번에 맞춘다.
    private func apply() {
        if settings.mascotID != lastMascotID {
            lastMascotID = settings.mascotID
            flash.reset() // 캐릭터마다 단계가 달라 바꾼 직후에는 대사를 띄우지 않는다
        }
        menu.refreshChecks()
        updateLength()
        render()
    }
```

- [ ] **Step 3:** `render`의 글자를 `StatusTitle.text(percent: settings.showsPercent ? value : nil, phrase: phraseVisible ? text : nil)`로 바꾸고, `updateLength`에 `percentWidth`(켜져 있으면 `StatusTitle.widestPercent`의 폭)를 넘긴다. 버튼 글꼴은 `NSFont.monospacedDigitSystemFont(ofSize: NSFont.menuBarFont(ofSize: 0).pointSize, weight: .regular)`.
- [ ] **Step 4:** `swift build` 경고 없음, `swift test` 전부 통과.

### Task 6: 로그인 시 실행

**Files:**
- Create: `Sources/Dallyeora/LoginItem.swift`
- Modify: `Sources/Dallyeora/StatusMenu.swift`

**Interfaces:**
- Produces: `LoginItem`(`isAvailable`, `isEnabled`, `needsApproval`, `setEnabled(_:) throws`, `openSystemSettings()`)

- [ ] **Step 1:**

```swift
import Foundation
import ServiceManagement

/// 로그인 항목 등록. 상태는 앱이 저장하지 않고 시스템에 묻는다.
@MainActor
struct LoginItem {
    /// `swift run`처럼 .app 번들 밖에서 뜨면 등록할 대상이 없다.
    var isAvailable: Bool { Bundle.main.bundleURL.pathExtension == "app" }
    var isEnabled: Bool { SMAppService.mainApp.status == .enabled }
    var needsApproval: Bool { SMAppService.mainApp.status == .requiresApproval }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
```

- [ ] **Step 2:** `StatusMenu`에 "로그인 시 실행" 항목을 넣는다. `refreshChecks`에서 `isEnabled`로 체크하고 `isAvailable`로 활성화한다. 액션은 `setEnabled(!isEnabled)`를 부르고, 던지면 `NSAlert`(제목 "로그인 시 실행을 바꾸지 못했습니다", 설명 `error.localizedDescription`)를 띄우며, 끝난 뒤 `needsApproval`이면 `openSystemSettings()`를 부른다.
- [ ] **Step 3:** `swift build` 경고 없음.

### Task 7: 화면이 꺼지면 멈춤

**Files:**
- Create: `Sources/Dallyeora/ActivityMonitor.swift`
- Modify: `Sources/Dallyeora/StatusItemController.swift`, `Sources/Dallyeora/Cleanup/CleanupWindowController.swift`

**Interfaces:**
- Consumes: `ActivityState`
- Produces: `ActivityMonitor(onChange: @escaping (Bool) -> Void)`, `CleanupWindowController.setActive(_:)`

- [ ] **Step 1:** `ActivityMonitor`는 `NSWorkspace.shared.notificationCenter`에서 `screensDidSleepNotification`, `screensDidWakeNotification`, `sessionDidResignActiveNotification`, `sessionDidBecomeActiveNotification`을 `queue: .main`으로 듣고, `state.handle(event)`가 true면 `onChange(state.isActive)`를 부른다.
- [ ] **Step 2:** 컨트롤러에 `setActive(_:)`를 넣는다. false면 `sampleTimer`, `frameTimer`를 끊고, true면 `sampler.sample()` → `startSampleTimer()` → `render()` → `scheduleNextFrame()`. 두 경우 모두 `cleanup.setActive`로 넘긴다.
- [ ] **Step 3:** `CleanupWindowController.setActive`는 창이 보일 때만 `model.start()` 또는 `model.stop()`을 부른다.
- [ ] **Step 4:** `swift build` 경고 없음.

### Task 8: 전역 단축키

**Files:**
- Create: `Sources/Dallyeora/GlobalHotKey.swift`
- Modify: `Sources/Dallyeora/StatusItemController.swift`

**Interfaces:**
- Produces: `GlobalHotKey(action:)`, `register() -> Bool`(⌃⌥⌘D)

- [ ] **Step 1:** Carbon `InstallEventHandler`(`kEventClassKeyboard`/`kEventHotKeyPressed`)와 `RegisterEventHotKey`(`kVK_ANSI_D`, `controlKey | optionKey | cmdKey`)로 구현한다. 핸들러는 C 함수 포인터라 `Unmanaged.passUnretained(self)`를 userData로 넘기고 `MainActor.assumeIsolated`로 `action()`을 부른다. 둘 중 하나라도 `noErr`가 아니면 false.
- [ ] **Step 2:** 컨트롤러가 `GlobalHotKey { [weak self] in self?.openCleanup() }`을 갖고 `menu.setCleanupShortcutVisible(hotKey.register())`를 부른다.
- [ ] **Step 3:** `swift build` 경고 없음.

### Task 9: 정리하기 창 (지표 공유, 검색, 줄 고정, 종료 확인, 상태 줄)

**Files:**
- Modify: `Sources/Dallyeora/Cleanup/AppTerminator.swift`, `CleanupModel.swift`, `CleanupView.swift`, `CleanupWindowController.swift`, `Sources/Dallyeora/StatusItemController.swift`

**Interfaces:**
- Consumes: `Settings.didChange`, `RowFilter`, `StableOrder`, `CleanupNotice`, `SignalResult`
- Produces: `CleanupModel(settings:)`, `.query`, `.isHovering`, `.notice: String?`, `.emptyText: String?`, `.clearTransientState()`; `CleanupWindowController(settings:)`, `.show()`; `AppTerminator.terminateProcess(_:) -> SignalResult`

- [ ] **Step 1:** `AppTerminator.terminateProcess`가 `SignalResult(killResult: kill(pid, SIGTERM), errno: errno)`를 돌려주게 한다.
- [ ] **Step 2: 모델.**
  - `init(settings:)`로 바꾸고 `metric`의 `didSet`에서 값이 바뀌었으면 기억한 순서를 버리고 `settings.metric`에 쓴 뒤 `rebuild()`. `Settings.didChange`를 받으면 `metric`이 다를 때만 맞춘다.
  - `query`(didSet → `rebuild()`), `isHovering`(didSet → 켜지면 현재 줄 id와 줄별 pid 순서를 기억, 꺼지면 버리고 `rebuild()`).
  - `rebuild()`는 줄을 만든 뒤 `StableOrder.arrange`로 순서를 정하고, 마우스가 올라가 있으면 그 결과를 다시 기억하며, `RowFilter`로 거른 것을 `rows`에 넣는다. 걸러서 비었으면 `emptyText = "'\(검색어)'에 맞는 항목이 없습니다"`.
  - 종료를 요청한 줄이 목록에서 사라지면 `.quit(app:)`을 알린다. 이름은 요청할 때 `pendingNames[id]`에 적어 둔다.
  - `quit`은 보내지 못하면 `.quitNotSent`, 10초 뒤 살아 있으면 `.unresponsive`. `forceQuit`은 결과에 따라 `.forceQuit` 또는 `.forceQuitFailed`.
  - `quit(member:)`는 `SignalResult`에 따라 바로 알리거나(`.notPermitted`, `.noSuchProcess`, `.failed`), `.sent`면 0.5초 뒤 다시 읽고 살아 있는지 보아 `.processEnded` 또는 `.processStillRunning`을 알린다.
  - `post(_:)`는 `notice`에 문구를 넣고 `CleanupNotice.duration` 뒤에 지운다.
- [ ] **Step 3: 뷰.** 위 줄에 세그먼트와 검색 칸(`TextField("검색", …)`, 폭 180, `@FocusState`, `.onExitCommand`로 비움)을 두고, 보이지 않는 `Button`에 `.keyboardShortcut("f")`를 달아 포커스를 준다. 목록에 `.onHover { model.isHovering = $0 }`. `emptyText`가 있으면 목록 자리에 그 글자. 맨 아래에 `Text(model.notice ?? " ")` 한 줄. 프로세스 "종료"는 `confirmQuitMember`를 부른다.
- [ ] **Step 4: 창 컨트롤러.** `init(settings:)`, `show()`. 프로세스 종료 확인 `NSAlert`(스펙 3.5 문구)를 띄우고 "종료"면 `model.quit(member:)`. `windowWillClose`에서 `model.stop()`과 `model.clearTransientState()`(검색어, 마우스 상태, 상태 줄).
- [ ] **Step 5:** `swift build` 경고 없음, `swift test` 전부 통과.

### Task 10: 문서와 손 확인

**Files:**
- Modify: `docs/spec-cleanup.md`(2절 제외 목록과 3.3의 지표 문장), `CLAUDE.md`(구조), `README.md`, `README.en.md`

- [ ] **Step 1:** `spec-cleanup.md`에서 "창의 지표 선택은 저장하지 않는다"와 "여기서 바꿔도 메뉴 막대 지표나 설정은 바뀌지 않는다"를 지표 공유로 고치고 `spec-usability.md`를 가리킨다. `CLAUDE.md`에 새 파일과 `docs/spec-usability.md`를 적는다.
- [ ] **Step 2:** `scripts/make-app.sh 0.6.0`으로 만든 앱에서 스펙 5절의 손 확인 항목을 본다. 자동으로 확인할 수 없는 항목은 사용자에게 넘기고 "미검증"으로 보고한다.
- [ ] **Step 3:** README 두 개를 고치고(로그인 시 실행 메뉴, 사용률 표시, 검색·줄 고정·단축키, 한계 절) 커밋하지 않은 채 diff를 사용자에게 보여 준다.
- [ ] **Step 4:** `defaults delete com.cozynye.dallyeora.tests`. 커밋과 릴리스는 사용자 승인 뒤에 한다.

### Task 11: 새 버전 알림 (스펙 3.7, 설계 뒤에 추가)

**Files:**
- Create: `Sources/DallyeoraCore/Update/AppVersion.swift`, `Sources/DallyeoraCore/Update/UpdateCheck.swift`, `Sources/Dallyeora/UpdateChecker.swift`
- Modify: `Sources/DallyeoraCore/Settings.swift`, `Sources/Dallyeora/StatusMenu.swift`, `Sources/Dallyeora/StatusItemController.swift`
- Test: `Tests/DallyeoraCoreTests/UpdateTests.swift`, `Tests/DallyeoraCoreTests/SettingsTests.swift`

**Interfaces:**
- Produces: `AppVersion(_:)`(실패 가능, `Comparable`), `UpdateCheck.latestVersion(inReleaseJSON:)`, `UpdateCheck.isDue(last:now:)`, `UpdateCheck.newer(latest:than:)`, `UpdateCheck.interval`(86400), `Settings.checksForUpdates`(기본 true), `UpdateChecker(settings:)`(`isAvailable`, `newerVersion`, `onChange`, `start()`)

- [ ] **Step 1:** `UpdateTests`에 버전 읽기와 거르기(`0.6.0-beta`, `1..2` 등), 숫자 비교(`0.10.0 > 0.9.0`, `0.6 == 0.6.0`), 응답 해석(사용량 제한 응답, 태그가 숫자가 아닌 경우, 빈 데이터), 확인 주기(기록 없음, 한 시간 전, 하루 전, 미래), 높은 버전만 알리기를 적는다. `SettingsTests`에 `checksForUpdates` 기본값과 저장을 적는다.
- [ ] **Step 2:** 컴파일 실패를 확인하고 Core를 구현한 뒤 `swift test` 통과.
- [ ] **Step 3:** `UpdateChecker`와 메뉴 항목 둘("새 버전 <번호> 받기", "새 버전 자동 확인")을 넣는다.
- [ ] **Step 4:** 버전을 0.4.0으로 만든 앱을 띄워 `defaults read com.cozynye.dallyeora`에 `latestKnownVersion`이 생기는지, `checksForUpdates`를 false로 두면 생기지 않는지 확인한다.

