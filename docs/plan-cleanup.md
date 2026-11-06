# 정리하기 창 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 메뉴의 "정리하기…"로 창을 열어, CPU·메모리를 많이 쓰는 것을 앱 단위로 묶어 한국어 설명과 함께 보여 주고 내 앱을 끌 수 있게 한다.

**Architecture:** `DallyeoraCore`에 프로세스 읽기(`ProcessReader`), 묶기(`ProcessGrouper`), 순위(`UsageRanker`), 사전(`ProcessCatalog`)을 순수 함수로 두고 테스트한다. `Dallyeora`에는 `CleanupModel`(@Observable)이 이 넷을 이어 화면용 행을 만들고, SwiftUI `CleanupView`를 `NSHostingView`로 `NSWindow`에 넣는다. 종료는 `NSRunningApplication`으로 한다.

**Tech Stack:** Swift 6 (strict concurrency), Swift Package, macOS 14+, AppKit, SwiftUI(창 내용만), Observation, libproc/sysctl, Swift Testing.

**Spec:** `docs/spec-cleanup.md`

## Global Constraints

- Swift tools 6.0, `platforms: [.macOS(.v14)]`, strict concurrency. 경고 없이 빌드되어야 한다.
- Core 타깃(`Sources/DallyeoraCore`)은 AppKit·SwiftUI를 import하지 않는다. Foundation·Darwin·CoreGraphics만.
- 사설 API 금지. `proc_listallpids`, `proc_pidpath`, `proc_pid_rusage`, `sysctl KERN_PROC_PID`, `mach_timebase_info`만 쓴다.
- 사용률 값은 항상 `Usage.clamp`를 거쳐 0–100.
- 사용자에게 보이는 문구는 모두 한국어, 평서체. 스펙 3.3·3.6·3.7의 문구를 글자 그대로 쓴다.
- 커밋 메시지에 `Co-Authored-By` 등 클로드 표시를 넣지 않는다. 각 태스크 끝에 로컬 커밋만 한다(push 금지).
- README는 고치되 커밋하지 않고 사용자에게 보여 준다(Task 8).
- 테스트 뒤 `defaults delete com.cozynye.dallyeora.tests`로 정리한다(기존 SettingsTests 때문).

## Review Focus

1. 스냅샷 중 끝난 프로세스: `proc_listallpids` 뒤 `sysctl`이 0바이트를 돌려주면 그 pid는 조용히 건너뛴다. 창이 비거나 크래시하면 안 된다. (Task 5 `kinfo` guard)
2. 부모 pid 순환이나 재사용: ppid 체인을 따라가다 같은 pid를 다시 만나거나 10단계를 넘으면 멈춘다. (Task 2 `parentCycleStops`)
3. CPU 시간이 줄어든 pid(종료 뒤 번호가 재사용됨): 음수 차이는 0으로 친다. (Task 3 `reusedPIDWithSmallerCPUIsIgnored`)
4. 사용률이 같은 묶음이 많을 때 줄 순서가 갱신마다 바뀌면 안 된다: 같은 값은 id 순. (Task 3 `tiesAreOrderedByID`)
5. 강제 종료로 저장하지 않은 작업을 잃는 것: `NSAlert` 확인 뒤에만 `forceTerminate`. (Task 7, 눈으로 확인)

---

## File Structure

| 파일 | 책임 |
|---|---|
| `Sources/DallyeoraCore/Processes/ProcessSample.swift` | `ProcessSample`, `ProcessSnapshot` |
| `Sources/DallyeoraCore/Processes/ProcessGroup.swift` | `ProcessGroup`과 `Kind` |
| `Sources/DallyeoraCore/Processes/ProcessGrouper.swift` | 묶기 규칙 |
| `Sources/DallyeoraCore/Processes/UsageRanker.swift` | `RankedRow`, 순위·잔여·그 외 계산 |
| `Sources/DallyeoraCore/Processes/ProcessCatalog.swift` | `ProcessDescription`, `CatalogEntry`, 찾기와 폴백 |
| `Sources/DallyeoraCore/Processes/CatalogEntries.swift` | 사전 데이터 |
| `Sources/DallyeoraCore/Processes/AppBundleInfo.swift` | 번들 ID·현지화 이름 |
| `Sources/DallyeoraCore/Processes/ProcessReader.swift` | libproc/sysctl 읽기 |
| `Sources/DallyeoraCore/UsageFormat.swift` | 바이트·퍼센트 문자열 |
| `Sources/DallyeoraCore/MemoryUsage.swift` (수정) | `usedBytes` |
| `Sources/Dallyeora/Cleanup/AppTerminator.swift` | `NSRunningApplication` 감싸기 |
| `Sources/Dallyeora/Cleanup/CleanupModel.swift` | 스냅샷→행, 타이머, 종료 상태 |
| `Sources/Dallyeora/Cleanup/CleanupView.swift` | SwiftUI 화면 |
| `Sources/Dallyeora/Cleanup/CleanupWindowController.swift` | 창 생성·재사용·활성화 |
| `Sources/Dallyeora/StatusItemController.swift` (수정) | 메뉴 항목 |
| `Tests/DallyeoraCoreTests/{UsageFormat,ProcessGrouper,UsageRanker,ProcessCatalog,ProcessReader}Tests.swift`, `MemoryUsageTests.swift` (수정) | 테스트 |

---

### Task 1: 표본 타입, 바이트 포맷, usedBytes

**Files:**
- Create: `Sources/DallyeoraCore/Processes/ProcessSample.swift`
- Create: `Sources/DallyeoraCore/UsageFormat.swift`
- Modify: `Sources/DallyeoraCore/MemoryUsage.swift`
- Test: `Tests/DallyeoraCoreTests/UsageFormatTests.swift`, `Tests/DallyeoraCoreTests/MemoryUsageTests.swift`

**Interfaces:**
- Produces: `ProcessSample(pid:ppid:uid:name:path:footprintBytes:cpuTimeNanos:)`, `ProcessSnapshot(uptime:samples:)`, `ProcessSnapshot.cpuTimeByPID: [pid_t: UInt64]`, `UsageFormat.bytes(_ UInt64) -> String`, `UsageFormat.percent(_ Double) -> String`, `MemoryUsage.usedBytes(_:pageSize:) -> UInt64`

- [ ] **Step 1: 실패하는 테스트 작성**

`Tests/DallyeoraCoreTests/UsageFormatTests.swift`:
```swift
import Testing
@testable import DallyeoraCore

struct UsageFormatTests {
    @Test(arguments: [
        (UInt64(0), "0 B"), (UInt64(1023), "1023 B"), (UInt64(1024), "1 KB"),
        (UInt64(1_048_576), "1 MB"), (UInt64(429_916_160), "410 MB"),
        (UInt64(1_610_612_736), "1.5 GB"), (UInt64(17_179_869_184), "16.0 GB"),
    ])
    func formatsBytesInBinaryUnits(value: UInt64, expected: String) {
        #expect(UsageFormat.bytes(value) == expected)
    }

    @Test(arguments: [(36.6, "37%"), (0.4, "0%"), (250.0, "100%"), (Double.nan, "0%")])
    func formatsPercentRounded(value: Double, expected: String) {
        #expect(UsageFormat.percent(value) == expected)
    }
}
```

`Tests/DallyeoraCoreTests/MemoryUsageTests.swift`에 추가:
```swift
    @Test func usedBytesMultipliesPages() {
        let p = MemoryPages(total: 1000, internal: 350, purgeable: 50, wired: 100, compressed: 100)
        #expect(MemoryUsage.usedBytes(p, pageSize: 4096) == 500 * 4096)
    }

    @Test func snapshotIndexesCPUTimeByPID() {
        let snap = ProcessSnapshot(uptime: 10, samples: [
            ProcessSample(pid: 1, ppid: 0, uid: 0, name: "a", path: "/a", footprintBytes: 1, cpuTimeNanos: 5),
            ProcessSample(pid: 2, ppid: 1, uid: 0, name: "b", path: "/b", footprintBytes: 2, cpuTimeNanos: 7),
        ])
        #expect(snap.cpuTimeByPID == [1: 5, 2: 7])
    }
```

- [ ] **Step 2: 실패 확인**

Run: `swift test --filter "UsageFormatTests|MemoryUsageTests" 2>&1 | grep -E "error:" | sort -u | head`
Expected: `cannot find 'UsageFormat' in scope`, `has no member 'usedBytes'`, `cannot find 'ProcessSnapshot' in scope`

- [ ] **Step 3: 구현**

`Sources/DallyeoraCore/Processes/ProcessSample.swift`:
```swift
import Foundation

/// 프로세스 하나의 표본. 다른 사용자 소유면 읽을 권한이 없어 footprint와 CPU 시간이 0이다.
public struct ProcessSample: Equatable, Sendable {
    public var pid: pid_t
    public var ppid: pid_t
    public var uid: uid_t
    public var name: String
    public var path: String
    public var footprintBytes: UInt64
    public var cpuTimeNanos: UInt64

    public init(pid: pid_t, ppid: pid_t, uid: uid_t, name: String, path: String,
                footprintBytes: UInt64 = 0, cpuTimeNanos: UInt64 = 0) {
        self.pid = pid
        self.ppid = ppid
        self.uid = uid
        self.name = name
        self.path = path
        self.footprintBytes = footprintBytes
        self.cpuTimeNanos = cpuTimeNanos
    }
}

/// 한 시점의 프로세스 전체. `uptime`은 시스템 가동 시간(초)으로 단조 증가한다.
public struct ProcessSnapshot: Equatable, Sendable {
    public var uptime: TimeInterval
    public var samples: [ProcessSample]

    public init(uptime: TimeInterval, samples: [ProcessSample]) {
        self.uptime = uptime
        self.samples = samples
    }

    /// 다음 스냅샷과 pid별로 CPU 시간을 비교할 때 쓴다.
    public var cpuTimeByPID: [pid_t: UInt64] {
        Dictionary(samples.map { ($0.pid, $0.cpuTimeNanos) }, uniquingKeysWith: { a, _ in a })
    }
}
```

`Sources/DallyeoraCore/UsageFormat.swift`:
```swift
import Foundation

public enum UsageFormat {
    /// 1024 기준. GB는 소수 한 자리, MB와 KB는 정수, 1 KB 미만은 B.
    public static func bytes(_ value: UInt64) -> String {
        let kb = 1024.0, mb = kb * 1024, gb = mb * 1024
        let v = Double(value)
        if v >= gb { return String(format: "%.1f GB", v / gb) }
        if v >= mb { return String(format: "%.0f MB", v / mb) }
        if v >= kb { return String(format: "%.0f KB", v / kb) }
        return "\(value) B"
    }

    public static func percent(_ value: Double) -> String {
        "\(Int(Usage.clamp(value).rounded()))%"
    }
}
```

`Sources/DallyeoraCore/MemoryUsage.swift`의 `MemoryUsage` enum에 추가:
```swift
    /// 사용 중인 메모리를 바이트로. 정리하기 창에서 시스템 몫을 계산할 때 쓴다.
    public static func usedBytes(_ pages: MemoryPages, pageSize: UInt64 = UInt64(getpagesize())) -> UInt64 {
        pages.used * pageSize
    }
```

- [ ] **Step 4: 통과 확인**

Run: `swift test 2>&1 | grep -E "error|warning:|✘|Test run with"; defaults delete com.cozynye.dallyeora.tests 2>/dev/null; true`
Expected: `✔ Test run with 35 tests in 9 suites passed` (기존 31 + 포맷 2 + 메모리 2. 매개변수 테스트는 1개로 센다). 경고 없음.

- [ ] **Step 5: 커밋**

```bash
git add Sources/DallyeoraCore/Processes/ProcessSample.swift Sources/DallyeoraCore/UsageFormat.swift Sources/DallyeoraCore/MemoryUsage.swift Tests/DallyeoraCoreTests/UsageFormatTests.swift Tests/DallyeoraCoreTests/MemoryUsageTests.swift
git commit -m "feat: add process sample types and usage formatting"
```

---

### Task 2: 묶기 규칙

**Files:**
- Create: `Sources/DallyeoraCore/Processes/ProcessGroup.swift`
- Create: `Sources/DallyeoraCore/Processes/ProcessGrouper.swift`
- Test: `Tests/DallyeoraCoreTests/ProcessGrouperTests.swift`

**Interfaces:**
- Consumes: `ProcessSample`, `ProcessSnapshot` (Task 1)
- Produces: `ProcessGroup(id:kind:pids:footprintBytes:cpuTimeNanos:)`, `ProcessGroup.Kind { .app(bundlePath: String, mainPID: pid_t) | .background(name: String) | .system(count: Int) }`, `ProcessGrouper.appBundlePath(of:) -> String?`, `ProcessGrouper.group(_:currentUID:selfPID:) -> [ProcessGroup]` (시스템 묶음은 있으면 항상 마지막, id `"system"`)

- [ ] **Step 1: 실패하는 테스트 작성**

`Tests/DallyeoraCoreTests/ProcessGrouperTests.swift`:
```swift
import Foundation
import Testing
@testable import DallyeoraCore

struct ProcessGrouperTests {
    static let chrome = "/Applications/Google Chrome.app"
    static let chromeHelper = chrome + "/Contents/Frameworks/Google Chrome Framework.framework/Versions/1/Helpers/Google Chrome Helper (Renderer).app/Contents/MacOS/Google Chrome Helper (Renderer)"
    static let cursor = "/Applications/Cursor.app"
    static let terminal = "/System/Applications/Utilities/Terminal.app"

    func s(_ pid: pid_t, _ ppid: pid_t, _ path: String, uid: uid_t = 501, mem: UInt64 = 0, cpu: UInt64 = 0) -> ProcessSample {
        ProcessSample(pid: pid, ppid: ppid, uid: uid, name: (path as NSString).lastPathComponent, path: path,
                      footprintBytes: mem, cpuTimeNanos: cpu)
    }

    func group(_ samples: [ProcessSample], selfPID: pid_t = 999) -> [ProcessGroup] {
        ProcessGrouper.group(ProcessSnapshot(uptime: 1, samples: samples), currentUID: 501, selfPID: selfPID)
    }

    @Test func findsOutermostAppBundle() {
        #expect(ProcessGrouper.appBundlePath(of: Self.chromeHelper) == Self.chrome)
        #expect(ProcessGrouper.appBundlePath(of: "/System/Library/CoreServices/Finder.app/Contents/MacOS/Finder") == "/System/Library/CoreServices/Finder.app")
        #expect(ProcessGrouper.appBundlePath(of: "/opt/homebrew/bin/node") == nil)
        #expect(ProcessGrouper.appBundlePath(of: "") == nil)
    }

    @Test func helpersGroupUnderTheirApp() {
        let groups = group([
            s(10, 1, Self.chrome + "/Contents/MacOS/Google Chrome", mem: 100, cpu: 5),
            s(11, 10, Self.chromeHelper, mem: 50, cpu: 1),
            s(12, 10, Self.chromeHelper, mem: 50, cpu: 1),
        ])
        #expect(groups.count == 1)
        #expect(groups[0].id == Self.chrome)
        #expect(groups[0].kind == .app(bundlePath: Self.chrome, mainPID: 10))
        #expect(groups[0].pids == [10, 11, 12])
        #expect(groups[0].footprintBytes == 200)
        #expect(groups[0].cpuTimeNanos == 7)
    }

    @Test func orphanPathFollowsParentChainToApp() {
        let groups = group([
            s(20, 1, Self.cursor + "/Contents/MacOS/Cursor"),
            s(21, 20, Self.cursor + "/Contents/Frameworks/Cursor Helper (Plugin).app/Contents/MacOS/Cursor Helper (Plugin)"),
            s(22, 21, "/opt/homebrew/bin/node", mem: 300),
        ])
        #expect(groups.count == 1)
        #expect(groups[0].pids == [20, 21, 22])
        #expect(groups[0].footprintBytes == 300)
    }

    @Test func chainPassesThroughRootOwnedAncestor() {
        // 터미널 → login(root) → zsh → python
        let groups = group([
            s(30, 1, Self.terminal + "/Contents/MacOS/Terminal"),
            s(31, 30, "/usr/bin/login", uid: 0),
            s(32, 31, "/bin/zsh"),
            s(33, 32, "/usr/bin/python3", mem: 10),
        ])
        let terminal = groups.first { $0.id == Self.terminal }
        #expect(terminal?.pids == [30, 32, 33])
        #expect(groups.last?.kind == .system(count: 1))
    }

    @Test func processesWithoutAppGroupByName() {
        let groups = group([
            s(40, 1, "/System/Library/Frameworks/CoreServices.framework/Frameworks/Metadata.framework/Versions/A/Support/mds_stores", mem: 1),
            s(41, 1, "/System/Library/Frameworks/CoreServices.framework/Frameworks/Metadata.framework/Versions/A/Support/mds_stores", mem: 2),
            s(42, 1, "/System/Library/Frameworks/CoreServices.framework/Frameworks/Metadata.framework/Versions/A/Support/mds_stores", mem: 3),
        ])
        #expect(groups.count == 1)
        #expect(groups[0].id == "name:mds_stores")
        #expect(groups[0].kind == .background(name: "mds_stores"))
        #expect(groups[0].footprintBytes == 6)
    }

    @Test func otherUsersCollapseIntoOneSystemGroupAtTheEnd() {
        let groups = group([
            s(50, 1, "/usr/libexec/opendirectoryd", uid: 0, mem: 999),
            s(51, 1, "/System/Library/PrivateFrameworks/SkyLight.framework/Resources/WindowServer", uid: 88),
            s(52, 1, "/usr/bin/foo"),
        ])
        #expect(groups.count == 2)
        #expect(groups.last?.id == ProcessGrouper.systemID)
        #expect(groups.last?.kind == .system(count: 2))
        #expect(groups.last?.pids.isEmpty == true)
        #expect(groups.last?.footprintBytes == 0)
    }

    @Test func selfIsExcluded() {
        let groups = group([s(60, 1, "/usr/bin/foo"), s(61, 1, "/usr/bin/bar")], selfPID: 60)
        #expect(groups.map(\.id) == ["name:bar"])
    }

    @Test func parentCycleStops() {
        let groups = group([s(70, 71, "/usr/bin/a"), s(71, 70, "/usr/bin/b")])
        #expect(groups.map(\.id) == ["name:a", "name:b"])
    }

    @Test func mainPIDFallsBackToSmallestPID() {
        let groups = group([s(81, 1, Self.chromeHelper), s(80, 1, Self.chromeHelper)])
        #expect(groups[0].kind == .app(bundlePath: Self.chrome, mainPID: 80))
    }
}
```

- [ ] **Step 2: 실패 확인**

Run: `swift test --filter ProcessGrouperTests 2>&1 | grep -E "error:" | sort -u | head -3`
Expected: `cannot find 'ProcessGrouper' in scope`, `cannot find type 'ProcessGroup' in scope`

- [ ] **Step 3: 구현**

`Sources/DallyeoraCore/Processes/ProcessGroup.swift`:
```swift
import Foundation

/// 화면 한 줄이 되는 프로세스 묶음.
public struct ProcessGroup: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        /// 앱 번들로 묶임. `mainPID`는 종료 명령을 보낼 대표 프로세스.
        case app(bundlePath: String, mainPID: pid_t)
        /// 앱 번들이 없어 이름으로 묶임.
        case background(name: String)
        /// 다른 사용자 소유 전체. 수치는 없고 개수만.
        case system(count: Int)
    }

    public var id: String
    public var kind: Kind
    public var pids: [pid_t]
    public var footprintBytes: UInt64
    public var cpuTimeNanos: UInt64

    public init(id: String, kind: Kind, pids: [pid_t], footprintBytes: UInt64, cpuTimeNanos: UInt64) {
        self.id = id
        self.kind = kind
        self.pids = pids
        self.footprintBytes = footprintBytes
        self.cpuTimeNanos = cpuTimeNanos
    }
}
```

`Sources/DallyeoraCore/Processes/ProcessGrouper.swift`:
```swift
import Foundation

/// 스펙 3.4의 묶기 규칙.
public enum ProcessGrouper {
    public static let systemID = "system"
    static let maxParentDepth = 10

    /// 경로에서 가장 바깥의 `.app`까지. 없으면 nil.
    public static func appBundlePath(of path: String) -> String? {
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        guard let i = parts.firstIndex(where: { $0.hasSuffix(".app") }) else { return nil }
        return parts[...i].joined(separator: "/")
    }

    public static func group(_ snapshot: ProcessSnapshot, currentUID: uid_t, selfPID: pid_t) -> [ProcessGroup] {
        let samples = snapshot.samples.filter { $0.pid != selfPID }.sorted { $0.pid < $1.pid }
        let byPID = Dictionary(samples.map { ($0.pid, $0) }, uniquingKeysWith: { a, _ in a })
        var groups: [String: ProcessGroup] = [:]
        var order: [String] = []
        var systemCount = 0

        for s in samples {
            if s.uid != currentUID {
                systemCount += 1
                continue
            }
            let id: String
            let kind: ProcessGroup.Kind
            if let bundle = owningBundle(of: s, byPID: byPID) {
                id = bundle
                kind = .app(bundlePath: bundle, mainPID: 0) // 대표 pid는 아래서 정한다
            } else {
                id = "name:" + s.name
                kind = .background(name: s.name)
            }
            if groups[id] == nil {
                groups[id] = ProcessGroup(id: id, kind: kind, pids: [], footprintBytes: 0, cpuTimeNanos: 0)
                order.append(id)
            }
            groups[id]?.pids.append(s.pid)
            groups[id]?.footprintBytes += s.footprintBytes
            groups[id]?.cpuTimeNanos += s.cpuTimeNanos
        }

        var result = order.compactMap { groups[$0] }
        for i in result.indices {
            if case .app(let bundle, _) = result[i].kind {
                result[i].kind = .app(bundlePath: bundle, mainPID: mainPID(of: result[i], bundle: bundle, byPID: byPID))
            }
        }
        if systemCount > 0 {
            result.append(ProcessGroup(id: systemID, kind: .system(count: systemCount), pids: [], footprintBytes: 0, cpuTimeNanos: 0))
        }
        return result
    }

    /// 경로의 .app, 없으면 부모를 따라 올라가 찾은 .app. 순환이나 10단계를 넘으면 포기한다.
    static func owningBundle(of sample: ProcessSample, byPID: [pid_t: ProcessSample]) -> String? {
        if let bundle = appBundlePath(of: sample.path) { return bundle }
        var seen: Set<pid_t> = [sample.pid]
        var pid = sample.ppid
        var depth = 0
        while pid > 1, depth < maxParentDepth, !seen.contains(pid), let parent = byPID[pid] {
            if let bundle = appBundlePath(of: parent.path) { return bundle }
            seen.insert(pid)
            pid = parent.ppid
            depth += 1
        }
        return nil
    }

    /// `<번들>/Contents/MacOS/<이름>` 바로 아래 프로세스. 없으면 가장 작은 pid.
    static func mainPID(of group: ProcessGroup, bundle: String, byPID: [pid_t: ProcessSample]) -> pid_t {
        let prefix = bundle + "/Contents/MacOS/"
        let direct = group.pids.filter { pid in
            guard let path = byPID[pid]?.path, path.hasPrefix(prefix) else { return false }
            return !path.dropFirst(prefix.count).contains("/")
        }
        return direct.min() ?? group.pids.min() ?? 0
    }
}
```

- [ ] **Step 4: 통과 확인**

Run: `swift test 2>&1 | grep -E "error|warning:|✘|Test run with"; defaults delete com.cozynye.dallyeora.tests 2>/dev/null; true`
Expected: `✔ Test run with 44 tests in 10 suites passed`. 경고 없음.

- [ ] **Step 5: 커밋**

```bash
git add Sources/DallyeoraCore/Processes/ProcessGroup.swift Sources/DallyeoraCore/Processes/ProcessGrouper.swift Tests/DallyeoraCoreTests/ProcessGrouperTests.swift
git commit -m "feat: group processes by owning app bundle"
```

---

### Task 3: 순위와 잔여 계산

**Files:**
- Create: `Sources/DallyeoraCore/Processes/UsageRanker.swift`
- Test: `Tests/DallyeoraCoreTests/UsageRankerTests.swift`

**Interfaces:**
- Consumes: `ProcessGroup`, `ProcessSnapshot.cpuTimeByPID`, `Metric`, `Usage.clamp`
- Produces: `RankedRow(kind:group:count:memoryBytes:cpuPercent:)`, `RankedRow.Kind { .app, .background, .system, .others }`, `UsageRanker.Totals(cpuPercent: Double?, memoryBytes: UInt64)`, `UsageRanker.rank(groups:current:previous:cpuCount:totals:metric:limit:) -> [RankedRow]`, `UsageRanker.limit == 15`

- [ ] **Step 1: 실패하는 테스트 작성**

`Tests/DallyeoraCoreTests/UsageRankerTests.swift`:
```swift
import Testing
@testable import DallyeoraCore

struct UsageRankerTests {
    func sample(_ pid: pid_t, cpu: UInt64) -> ProcessSample {
        ProcessSample(pid: pid, ppid: 1, uid: 501, name: "p\(pid)", path: "/p\(pid)", footprintBytes: 0, cpuTimeNanos: cpu)
    }
    func app(_ id: String, pids: [pid_t], mem: UInt64 = 0) -> ProcessGroup {
        ProcessGroup(id: id, kind: .app(bundlePath: id, mainPID: pids[0]), pids: pids, footprintBytes: mem, cpuTimeNanos: 0)
    }
    func bg(_ name: String, pids: [pid_t], mem: UInt64 = 0) -> ProcessGroup {
        ProcessGroup(id: "name:" + name, kind: .background(name: name), pids: pids, footprintBytes: mem, cpuTimeNanos: 0)
    }
    let system = ProcessGroup(id: "system", kind: .system(count: 200), pids: [], footprintBytes: 0, cpuTimeNanos: 0)

    @Test func cpuUsesPerPIDDeltasAndIgnoresNewPIDs() {
        let prev = ProcessSnapshot(uptime: 100, samples: [sample(1, cpu: 1_000_000_000), sample(2, cpu: 500_000_000)])
        let cur = ProcessSnapshot(uptime: 102, samples: [sample(1, cpu: 2_000_000_000), sample(3, cpu: 9_000_000_000)])
        let rows = UsageRanker.rank(groups: [app("/A.app", pids: [1, 3])], current: cur, previous: prev,
                                    cpuCount: 4, totals: .init(cpuPercent: 50, memoryBytes: 0), metric: .cpu)
        // Δ = 1초 / (2초 × 4코어) = 12.5%
        #expect(rows[0].cpuPercent == 12.5)
        #expect(rows[0].kind == .app)
        #expect(rows[0].count == 2)
    }

    @Test func reusedPIDWithSmallerCPUIsIgnored() {
        let prev = ProcessSnapshot(uptime: 0, samples: [sample(1, cpu: 5_000_000_000)])
        let cur = ProcessSnapshot(uptime: 1, samples: [sample(1, cpu: 1_000)])
        let rows = UsageRanker.rank(groups: [bg("x", pids: [1])], current: cur, previous: prev,
                                    cpuCount: 1, totals: .init(cpuPercent: 0, memoryBytes: 0), metric: .cpu)
        #expect(rows[0].cpuPercent == 0)
    }

    @Test func noPreviousSnapshotMeansNoCPU() {
        let cur = ProcessSnapshot(uptime: 1, samples: [sample(1, cpu: 1)])
        let rows = UsageRanker.rank(groups: [app("/A.app", pids: [1]), system], current: cur, previous: nil,
                                    cpuCount: 4, totals: .init(cpuPercent: nil, memoryBytes: 1000), metric: .cpu)
        #expect(rows.allSatisfy { $0.cpuPercent == nil })
    }

    @Test func systemRowIsTheRemainder() {
        let cur = ProcessSnapshot(uptime: 1, samples: [])
        let rows = UsageRanker.rank(groups: [app("/A.app", pids: [1], mem: 300), system], current: cur, previous: nil,
                                    cpuCount: 4, totals: .init(cpuPercent: nil, memoryBytes: 1000), metric: .memory)
        let sys = rows.first { $0.kind == .system }
        #expect(sys?.memoryBytes == 700)
        #expect(sys?.count == 200)
    }

    @Test func remainderNeverGoesNegative() {
        let prev = ProcessSnapshot(uptime: 0, samples: [sample(1, cpu: 0)])
        let cur = ProcessSnapshot(uptime: 2, samples: [sample(1, cpu: 4_800_000_000)]) // 60% of 4 cores
        let rows = UsageRanker.rank(groups: [app("/A.app", pids: [1], mem: 1200), system], current: cur, previous: prev,
                                    cpuCount: 4, totals: .init(cpuPercent: 50, memoryBytes: 1000), metric: .memory)
        let sys = rows.first { $0.kind == .system }
        #expect(sys?.memoryBytes == 0)
        #expect(sys?.cpuPercent == 0)
    }

    @Test func sortsBySelectedMetric() {
        let prev = ProcessSnapshot(uptime: 0, samples: [sample(1, cpu: 0), sample(2, cpu: 0)])
        let cur = ProcessSnapshot(uptime: 1, samples: [sample(1, cpu: 1_000_000_000), sample(2, cpu: 0)])
        let groups = [app("/A.app", pids: [1], mem: 100), app("/B.app", pids: [2], mem: 500)]
        let byCPU = UsageRanker.rank(groups: groups, current: cur, previous: prev, cpuCount: 1,
                                     totals: .init(cpuPercent: 100, memoryBytes: 600), metric: .cpu)
        let byMemory = UsageRanker.rank(groups: groups, current: cur, previous: prev, cpuCount: 1,
                                        totals: .init(cpuPercent: 100, memoryBytes: 600), metric: .memory)
        #expect(byCPU.map { $0.group?.id } == ["/A.app", "/B.app"])
        #expect(byMemory.map { $0.group?.id } == ["/B.app", "/A.app"])
    }

    @Test func tiesAreOrderedByID() {
        let cur = ProcessSnapshot(uptime: 1, samples: [])
        let groups = [bg("zeta", pids: [1], mem: 5), bg("alpha", pids: [2], mem: 5), bg("mid", pids: [3], mem: 5)]
        let rows = UsageRanker.rank(groups: groups, current: cur, previous: nil, cpuCount: 1,
                                    totals: .init(cpuPercent: nil, memoryBytes: 15), metric: .memory)
        #expect(rows.map { $0.group?.id } == ["name:alpha", "name:mid", "name:zeta"])
    }

    @Test func collapsesRowsBeyondLimitIntoOthers() {
        let cur = ProcessSnapshot(uptime: 1, samples: [])
        let groups = (1...5).map { app("/\($0).app", pids: [pid_t($0)], mem: UInt64(100 * $0)) }
        let rows = UsageRanker.rank(groups: groups, current: cur, previous: nil, cpuCount: 1,
                                    totals: .init(cpuPercent: nil, memoryBytes: 1500), metric: .memory, limit: 3)
        #expect(rows.count == 4)
        #expect(rows.map { $0.group?.id } == ["/5.app", "/4.app", "/3.app", nil])
        #expect(rows[3].kind == .others)
        #expect(rows[3].count == 2)
        #expect(rows[3].memoryBytes == 300)
        #expect(UsageRanker.limit == 15)
    }
}
```

- [ ] **Step 2: 실패 확인**

Run: `swift test --filter UsageRankerTests 2>&1 | grep -E "error:" | sort -u | head -3`
Expected: `cannot find 'UsageRanker' in scope`

- [ ] **Step 3: 구현**

`Sources/DallyeoraCore/Processes/UsageRanker.swift`:
```swift
import Foundation

/// 정리하기 창의 한 줄.
public struct RankedRow: Equatable, Sendable {
    public enum Kind: Equatable, Sendable { case app, background, system, others }

    public var kind: Kind
    /// 그 외 줄은 nil.
    public var group: ProcessGroup?
    /// 앱·백그라운드는 pid 수, 시스템은 프로세스 수, 그 외는 묶음 수.
    public var count: Int
    public var memoryBytes: UInt64
    /// 직전 스냅샷이 없으면 nil("측정 중…").
    public var cpuPercent: Double?

    public init(kind: Kind, group: ProcessGroup?, count: Int, memoryBytes: UInt64, cpuPercent: Double?) {
        self.kind = kind
        self.group = group
        self.count = count
        self.memoryBytes = memoryBytes
        self.cpuPercent = cpuPercent
    }
}

/// 스펙 3.5의 계산.
public enum UsageRanker {
    public static let limit = 15

    public struct Totals: Equatable, Sendable {
        public var cpuPercent: Double?
        public var memoryBytes: UInt64

        public init(cpuPercent: Double?, memoryBytes: UInt64) {
            self.cpuPercent = cpuPercent
            self.memoryBytes = memoryBytes
        }
    }

    public static func rank(
        groups: [ProcessGroup], current: ProcessSnapshot, previous: ProcessSnapshot?,
        cpuCount: Int, totals: Totals, metric: Metric, limit: Int = limit
    ) -> [RankedRow] {
        let elapsed = previous.map { current.uptime - $0.uptime } ?? 0
        let canMeasureCPU = elapsed > 0 && cpuCount > 0
        let prevCPU = previous?.cpuTimeByPID ?? [:]
        let curCPU = current.cpuTimeByPID

        var own: [RankedRow] = []
        var system: ProcessGroup?
        for g in groups {
            if case .system = g.kind {
                system = g
                continue
            }
            var cpu: Double?
            if canMeasureCPU {
                // pid별 차이만 더한다. 새 pid나 줄어든 pid(번호 재사용)는 0.
                let delta = g.pids.reduce(UInt64(0)) { acc, pid in
                    guard let p = prevCPU[pid], let c = curCPU[pid], c >= p else { return acc }
                    return acc + (c - p)
                }
                cpu = Usage.clamp(Double(delta) / (elapsed * 1e9) / Double(cpuCount) * 100)
            }
            let kind: RankedRow.Kind = if case .app = g.kind { .app } else { .background }
            own.append(RankedRow(kind: kind, group: g, count: g.pids.count, memoryBytes: g.footprintBytes, cpuPercent: cpu))
        }

        var rows = own
        if let system, case .system(let count) = system.kind {
            let ownMemory = own.reduce(UInt64(0)) { $0 + $1.memoryBytes }
            let ownCPU = own.reduce(0.0) { $0 + ($1.cpuPercent ?? 0) }
            let cpu = canMeasureCPU ? totals.cpuPercent.map { max(0, $0 - ownCPU) } : nil
            let memory = totals.memoryBytes > ownMemory ? totals.memoryBytes - ownMemory : 0
            rows.append(RankedRow(kind: .system, group: system, count: count, memoryBytes: memory, cpuPercent: cpu))
        }

        rows.sort { a, b in
            let (va, vb) = (value(of: a, metric), value(of: b, metric))
            return va != vb ? va > vb : (a.group?.id ?? "") < (b.group?.id ?? "")
        }

        guard rows.count > limit else { return rows }
        let rest = rows[limit...]
        let others = RankedRow(
            kind: .others, group: nil, count: rest.count,
            memoryBytes: rest.reduce(UInt64(0)) { $0 + $1.memoryBytes },
            cpuPercent: canMeasureCPU ? rest.reduce(0.0) { $0 + ($1.cpuPercent ?? 0) } : nil
        )
        return Array(rows[..<limit]) + [others]
    }

    static func value(of row: RankedRow, _ metric: Metric) -> Double {
        metric == .cpu ? (row.cpuPercent ?? 0) : Double(row.memoryBytes)
    }
}
```

- [ ] **Step 4: 통과 확인**

Run: `swift test 2>&1 | grep -E "error|warning:|✘|Test run with"; defaults delete com.cozynye.dallyeora.tests 2>/dev/null; true`
Expected: `✔ Test run with 52 tests in 11 suites passed`. 경고 없음.

- [ ] **Step 5: 커밋**

```bash
git add Sources/DallyeoraCore/Processes/UsageRanker.swift Tests/DallyeoraCoreTests/UsageRankerTests.swift
git commit -m "feat: rank process groups and compute the system remainder"
```

---

### Task 4: 한국어 사전

**Files:**
- Create: `Sources/DallyeoraCore/Processes/ProcessCatalog.swift`
- Create: `Sources/DallyeoraCore/Processes/CatalogEntries.swift`
- Create: `Sources/DallyeoraCore/Processes/AppBundleInfo.swift`
- Test: `Tests/DallyeoraCoreTests/ProcessCatalogTests.swift`

**Interfaces:**
- Consumes: `ProcessGroup`
- Produces: `ProcessDescription(title:summary:source:isProtected:)`, `ProcessDescription.Source { .catalog, .appName, .pattern, .unknown, .system }`, `CatalogEntry(_ match: Match, _ title: String, _ summary: String, protected: Bool = false)`, `CatalogEntry.Match { .bundleID(String), .name(String), .namePrefix(String) }`, `ProcessCatalog.entries`, `ProcessCatalog.describe(_:bundleID:localizedName:)`, `ProcessCatalog.entry(bundleID:)`, `ProcessCatalog.entry(name:)`, `AppBundleInfo.bundleID(at:) -> String?`, `AppBundleInfo.displayName(at:) -> String`

- [ ] **Step 1: 실패하는 테스트 작성**

`Tests/DallyeoraCoreTests/ProcessCatalogTests.swift`:
```swift
import Testing
@testable import DallyeoraCore

struct ProcessCatalogTests {
    func app(_ bundle: String) -> ProcessGroup {
        ProcessGroup(id: bundle, kind: .app(bundlePath: bundle, mainPID: 1), pids: [1], footprintBytes: 0, cpuTimeNanos: 0)
    }
    func bg(_ name: String) -> ProcessGroup {
        ProcessGroup(id: "name:" + name, kind: .background(name: name), pids: [1], footprintBytes: 0, cpuTimeNanos: 0)
    }

    @Test func knownAppByBundleID() {
        let d = ProcessCatalog.describe(app("/Applications/Google Chrome.app"), bundleID: "com.google.Chrome", localizedName: "Google Chrome")
        #expect(d.title == "Google Chrome")
        #expect(d.source == .catalog)
        #expect(d.summary.contains("탭"))
        #expect(!d.isProtected)
    }

    @Test func unknownAppUsesLocalizedNameAndGenericSummary() {
        let d = ProcessCatalog.describe(app("/Applications/Foo.app"), bundleID: "com.example.foo", localizedName: "푸")
        #expect(d.title == "푸")
        #expect(d.summary == "Dock이나 메뉴 막대에 보이는 앱. 안 쓰면 꺼도 된다.")
        #expect(d.source == .appName)
    }

    @Test func unknownAppWithoutLocalizedNameUsesFolderName() {
        let d = ProcessCatalog.describe(app("/Applications/Foo Bar.app"), bundleID: nil, localizedName: nil)
        #expect(d.title == "Foo Bar")
    }

    @Test func systemAppsAreProtectedByFolderName() {
        for folder in ["Finder", "Dock", "Spotlight", "ControlCenter", "NotificationCenter", "WindowManager", "SystemUIServer", "loginwindow"] {
            let d = ProcessCatalog.describe(app("/System/Library/CoreServices/\(folder).app"), bundleID: nil, localizedName: nil)
            #expect(d.source == .catalog, "\(folder)")
            #expect(d.isProtected, "\(folder)")
        }
    }

    @Test func knownBackgroundByExactName() {
        let d = ProcessCatalog.describe(bg("mdworker_shared"), bundleID: nil, localizedName: nil)
        #expect(d.source == .catalog)
        #expect(d.title.contains("Spotlight"))
    }

    @Test func knownBackgroundByPrefix() {
        let d = ProcessCatalog.describe(bg("python3.12"), bundleID: nil, localizedName: nil)
        #expect(d.source == .catalog)
        #expect(d.title.contains("파이썬"))
    }

    @Test func helperPatternFallback() {
        let d = ProcessCatalog.describe(bg("Foo Helper (GPU)"), bundleID: nil, localizedName: nil)
        #expect(d.source == .pattern)
        #expect(d.title == "Foo Helper (GPU)")
        #expect(d.summary == "어떤 앱의 보조 프로세스. 그 앱을 닫으면 함께 사라진다.")
    }

    @Test(arguments: ["fooagent", "barfood", "com.apple.something.xpc"])
    func daemonPatternFallback(name: String) {
        let d = ProcessCatalog.describe(bg(name), bundleID: nil, localizedName: nil)
        #expect(d.source == .pattern)
        #expect(d.summary == "macOS 백그라운드 서비스. 보통 잠시 뒤 저절로 내려간다.")
    }

    @Test func unknownIsLabeledUnknown() {
        let d = ProcessCatalog.describe(bg("xyzzy"), bundleID: nil, localizedName: nil)
        #expect(d.source == .unknown)
        #expect(d.title == "xyzzy")
        #expect(d.summary == "무엇인지 알 수 없는 프로세스.")
    }

    @Test func systemRowDescriptionCarriesTheCount() {
        let g = ProcessGroup(id: "system", kind: .system(count: 241), pids: [], footprintBytes: 0, cpuTimeNanos: 0)
        let d = ProcessCatalog.describe(g, bundleID: nil, localizedName: nil)
        #expect(d.title == "macOS 시스템")
        #expect(d.summary == "시스템 프로세스 241개 (WindowServer, kernel_task 등). 권한이 없어 세부는 볼 수 없고 끌 수도 없다. 메모리는 근사치다.")
        #expect(d.source == .system)
        #expect(d.isProtected)
    }

    @Test func catalogCoversTheRequiredNames() {
        #expect(ProcessCatalog.entries.count >= 100)
        let names = [
            "Finder", "Dock", "Spotlight", "ControlCenter", "NotificationCenter", "WindowManager", "SystemUIServer", "loginwindow",
            "mdworker_shared", "corespotlightd", "photoanalysisd", "photolibraryd", "mediaanalysisd", "bird", "cloudd", "cloudphotod",
            "nsurlsessiond", "com.apple.WebKit.WebContent", "com.apple.WebKit.Networking", "com.apple.WebKit.GPU", "QuickLookUIService",
            "suggestd", "knowledgeconstructiond", "siriknowledged", "assistantd", "accountsd", "identityservicesd", "imagent", "sharingd",
            "rapportd", "secd", "trustd", "cfprefsd", "distnoted", "UserEventAgent", "lsd", "tccd",
            "kernel_task", "WindowServer", "launchd", "mds", "mds_stores", "backupd", "softwareupdated", "syspolicyd", "XprotectService",
            "coreaudiod", "opendirectoryd", "runningboardd",
            "node", "python3", "Python", "java", "ruby", "swift-frontend", "clang", "SourceKitService", "com.docker.backend",
            "com.docker.virtualization", "qemu-system-aarch64", "ollama", "gradle", "rustc", "cargo",
        ]
        for name in names {
            #expect(ProcessCatalog.entry(name: name) != nil, "\(name)")
        }
        let bundles = [
            "com.apple.Safari", "com.google.Chrome", "org.mozilla.firefox", "com.microsoft.edgemac", "com.brave.Browser", "com.naver.Whale",
            "company.thebrowser.Browser", "com.microsoft.VSCode", "com.todesktop.230313mzl4w4u92", "com.apple.dt.Xcode",
            "com.apple.iphonesimulator", "com.apple.Terminal", "com.googlecode.iterm2", "com.docker.docker", "com.tinyspeck.slackmacgap",
            "com.hnc.Discord", "notion.id", "com.kakao.KakaoTalkMac", "us.zoom.xos", "com.microsoft.teams2", "com.spotify.client",
            "com.apple.Music", "com.figma.Desktop", "com.postmanlabs.mac", "com.jetbrains.intellij", "com.microsoft.Word", "com.microsoft.Excel",
            "com.microsoft.Powerpoint", "com.adobe.Photoshop", "com.openai.chat", "com.anthropic.claudefordesktop", "com.1password.1password",
            "com.getdropbox.dropbox", "com.google.drivefs", "com.apple.Photos", "com.apple.mail", "com.apple.Notes", "com.apple.iCal",
            "com.apple.Preview", "com.apple.ActivityMonitor",
        ]
        for id in bundles {
            #expect(ProcessCatalog.entry(bundleID: id) != nil, "\(id)")
        }
    }

    @Test func readsBundleInfoFromDisk() {
        let preview = "/System/Applications/Preview.app"
        #expect(AppBundleInfo.bundleID(at: preview) == "com.apple.Preview")
        let name = AppBundleInfo.displayName(at: preview)
        #expect(!name.isEmpty)
        #expect(!name.hasSuffix(".app"))
        #expect(AppBundleInfo.bundleID(at: "/nonexistent/Nope.app") == nil)
    }
}
```

- [ ] **Step 2: 실패 확인**

Run: `swift test --filter ProcessCatalogTests 2>&1 | grep -E "error:" | sort -u | head -3`
Expected: `cannot find 'ProcessCatalog' in scope`, `cannot find 'AppBundleInfo' in scope`

- [ ] **Step 3: 구현 — 찾기와 폴백**

`Sources/DallyeoraCore/Processes/ProcessCatalog.swift`:
```swift
import Foundation

/// 화면에 보일 한국어 이름과 설명.
public struct ProcessDescription: Equatable, Sendable {
    public enum Source: Equatable, Sendable { case catalog, appName, pattern, unknown, system }

    public var title: String
    public var summary: String
    public var source: Source
    /// macOS 구성 요소. 끌 수 있어 보여도 버튼을 붙이지 않는다.
    public var isProtected: Bool
}

public struct CatalogEntry: Sendable {
    public enum Match: Equatable, Sendable {
        case bundleID(String)
        case name(String)
        case namePrefix(String)
    }

    public var match: Match
    public var title: String
    public var summary: String
    public var isProtected: Bool

    public init(_ match: Match, _ title: String, _ summary: String, protected: Bool = false) {
        self.match = match
        self.title = title
        self.summary = summary
        self.isProtected = protected
    }
}

/// 스펙 3.6의 사전과 폴백.
public enum ProcessCatalog {
    public static let entries: [CatalogEntry] = CatalogEntries.all

    public static func describe(_ group: ProcessGroup, bundleID: String?, localizedName: String?) -> ProcessDescription {
        switch group.kind {
        case .system(let count):
            return ProcessDescription(
                title: "macOS 시스템",
                summary: "시스템 프로세스 \(count)개 (WindowServer, kernel_task 등). 권한이 없어 세부는 볼 수 없고 끌 수도 없다. 메모리는 근사치다.",
                source: .system, isProtected: true)

        case .app(let bundlePath, _):
            let folder = ((bundlePath as NSString).lastPathComponent as NSString).deletingPathExtension
            if let e = bundleID.flatMap(entry(bundleID:)) ?? entry(name: folder) {
                return ProcessDescription(title: e.title, summary: e.summary, source: .catalog, isProtected: e.isProtected)
            }
            return ProcessDescription(title: localizedName ?? folder, summary: "Dock이나 메뉴 막대에 보이는 앱. 안 쓰면 꺼도 된다.",
                                      source: .appName, isProtected: false)

        case .background(let name):
            if let e = entry(name: name) {
                return ProcessDescription(title: e.title, summary: e.summary, source: .catalog, isProtected: e.isProtected)
            }
            if let summary = patternSummary(name) {
                return ProcessDescription(title: name, summary: summary, source: .pattern, isProtected: false)
            }
            return ProcessDescription(title: name, summary: "무엇인지 알 수 없는 프로세스.", source: .unknown, isProtected: false)
        }
    }

    static func entry(bundleID id: String) -> CatalogEntry? {
        entries.first { $0.match == .bundleID(id) }
    }

    /// 정확히 같은 이름을 먼저, 그다음 접두사.
    static func entry(name: String) -> CatalogEntry? {
        if let exact = entries.first(where: { $0.match == .name(name) }) { return exact }
        return entries.first { entry in
            if case .namePrefix(let prefix) = entry.match { return name.hasPrefix(prefix) }
            return false
        }
    }

    static func patternSummary(_ name: String) -> String? {
        let lower = name.lowercased()
        if ["helper", "renderer", "plugin"].contains(where: { lower.contains($0) }) {
            return "어떤 앱의 보조 프로세스. 그 앱을 닫으면 함께 사라진다."
        }
        if lower.hasPrefix("com.apple.") || lower.hasSuffix("d") || lower.hasSuffix("agent") {
            return "macOS 백그라운드 서비스. 보통 잠시 뒤 저절로 내려간다."
        }
        return nil
    }
}
```

`Sources/DallyeoraCore/Processes/AppBundleInfo.swift`:
```swift
import Foundation

public enum AppBundleInfo {
    public static func bundleID(at path: String) -> String? {
        Bundle(path: path)?.bundleIdentifier
    }

    /// Finder가 보여 주는 이름(예: 미리보기). 확장자가 붙어 오면 뗀다.
    public static func displayName(at path: String) -> String {
        let name = FileManager.default.displayName(atPath: path)
        return name.hasSuffix(".app") ? String(name.dropLast(4)) : name
    }
}
```

- [ ] **Step 4: 구현 — 사전 데이터**

`Sources/DallyeoraCore/Processes/CatalogEntries.swift`:
```swift
/// 사전 데이터. 설명은 "왜 올라가는지"와 "기다리면 내려가는지 / 끄려면 무엇을 닫는지"를 한 줄에 담는다.
enum CatalogEntries {
    private typealias E = CatalogEntry

    static let all: [CatalogEntry] = macOSApps + macOSAgents + systemOnly + apps + devTools

    /// `.app` 번들로 돌아가는 macOS 구성 요소. 폴더 이름으로 맞추고 보호한다.
    private static let macOSApps: [CatalogEntry] = [
        E(.name("Finder"), "Finder", "파일 창을 그리는 macOS 기본 앱. 끄면 바로 다시 켜진다.", protected: true),
        E(.name("Dock"), "Dock", "화면 아래 앱 막대와 미션 컨트롤. 끄면 바로 다시 켜진다.", protected: true),
        E(.name("Spotlight"), "Spotlight 검색", "검색 창. 검색을 열 때만 잠깐 올라간다.", protected: true),
        E(.name("ControlCenter"), "제어 센터", "메뉴 막대 오른쪽의 Wi‑Fi, 소리, 배터리 메뉴.", protected: true),
        E(.name("NotificationCenter"), "알림 센터", "알림과 위젯. 위젯이 많으면 메모리를 더 쓴다.", protected: true),
        E(.name("WindowManager"), "창 관리자", "스테이지 매니저와 창 배치. 창이 많을수록 올라간다.", protected: true),
        E(.name("SystemUIServer"), "메뉴 막대 시스템 항목", "시간, 입력기 같은 메뉴 막대의 시스템 아이콘을 그린다.", protected: true),
        E(.name("loginwindow"), "로그인 세션", "로그인 상태를 관리한다. 끄면 로그아웃된다.", protected: true),
        E(.name("Siri"), "Siri", "Siri 앱. 부르면 잠깐 올라간다.", protected: true),
        E(.name("TextInputMenuAgent"), "입력 소스 메뉴", "메뉴 막대의 입력기 전환 메뉴.", protected: true),
    ]

    /// 내 계정으로 도는 macOS 백그라운드 프로세스.
    private static let macOSAgents: [CatalogEntry] = [
        E(.name("mdworker_shared"), "Spotlight 색인 (mdworker_shared)", "Spotlight 검색 색인. 새 파일이 많이 생기면 한동안 바쁘다가 저절로 내려간다."),
        E(.namePrefix("mdworker"), "Spotlight 색인 (mdworker)", "Spotlight 검색 색인 작업자. 색인이 끝나면 내려간다."),
        E(.name("corespotlightd"), "앱 내용 색인 (corespotlightd)", "메모, 메시지 같은 앱 안의 내용을 Spotlight에 색인한다. 잠시 뒤 내려간다."),
        E(.name("photoanalysisd"), "사진 분석 (photoanalysisd)", "사진 앱의 얼굴·사물 분석. 사진을 많이 넣은 뒤 며칠간 돌 수 있다. 전원에 연결해 두면 밤에 끝난다."),
        E(.name("photolibraryd"), "사진 보관함 (photolibraryd)", "사진 보관함 관리와 iCloud 사진 동기화. 사진 앱을 닫아도 뒤에서 돈다."),
        E(.name("mediaanalysisd"), "미디어 분석 (mediaanalysisd)", "사진과 동영상 속 글자·사물 인식(라이브 텍스트). 미디어가 많으면 한동안 돈다."),
        E(.name("bird"), "iCloud Drive 동기화 (bird)", "iCloud Drive 파일 동기화. 파일을 많이 올리거나 받을 때 올라간다."),
        E(.name("cloudd"), "iCloud 동기화 (cloudd)", "연락처, 메모 같은 iCloud 데이터 동기화. 동기화가 끝나면 내려간다."),
        E(.name("cloudphotod"), "iCloud 사진 (cloudphotod)", "iCloud 사진 업로드와 다운로드. 사진이 많으면 오래 걸린다."),
        E(.name("fileproviderd"), "클라우드 폴더 연결 (fileproviderd)", "iCloud Drive, Dropbox, Google Drive 같은 클라우드 폴더를 Finder에 연결한다."),
        E(.name("nsurlsessiond"), "백그라운드 전송 (nsurlsessiond)", "앱들의 백그라운드 다운로드와 업로드를 대신 처리한다. 전송이 끝나면 내려간다."),
        E(.name("com.apple.WebKit.WebContent"), "Safari 웹 페이지 (WebContent)", "Safari(또는 WebKit을 쓰는 앱)의 웹 페이지. Safari 탭을 닫으면 줄어든다."),
        E(.name("com.apple.WebKit.Networking"), "Safari 네트워크 (WebKit.Networking)", "Safari의 네트워크 처리. 탭을 닫으면 줄어든다."),
        E(.name("com.apple.WebKit.GPU"), "Safari 그래픽 (WebKit.GPU)", "Safari의 화면 그리기와 동영상 재생. 동영상 탭을 닫으면 줄어든다."),
        E(.name("QuickLookUIService"), "훑어보기 (QuickLookUIService)", "스페이스 바로 여는 파일 미리 보기. 미리 보기 창을 닫으면 내려간다."),
        E(.name("quicklookd"), "미리 보기 생성 (quicklookd)", "파일 미리 보기 이미지를 만든다. 잠시 뒤 내려간다."),
        E(.name("com.apple.quicklook.ThumbnailsAgent"), "섬네일 생성", "Finder에 보이는 파일 섬네일을 만든다. 잠시 뒤 내려간다."),
        E(.name("iconservicesagent"), "아이콘 캐시 (iconservicesagent)", "앱과 파일 아이콘 캐시. 항상 작게 떠 있다."),
        E(.name("suggestd"), "제안 분석 (suggestd)", "메일과 메시지에서 연락처·일정을 찾아 제안한다. 잠시 뒤 내려간다."),
        E(.name("knowledgeconstructiond"), "Siri 제안 분석 (knowledgeconstructiond)", "Siri 제안을 위한 사용 기록 분석. 잠시 뒤 내려간다."),
        E(.name("siriknowledged"), "Siri 지식 (siriknowledged)", "Siri 지식 그래프. 잠시 뒤 내려간다."),
        E(.name("assistantd"), "Siri와 받아쓰기 (assistantd)", "Siri와 받아쓰기. 쓰지 않으면 거의 쉰다."),
        E(.name("parsecd"), "Spotlight 제안 (parsecd)", "Spotlight와 Safari의 인터넷 제안 검색."),
        E(.name("accountsd"), "계정 관리 (accountsd)", "Apple ID와 인터넷 계정 관리."),
        E(.name("identityservicesd"), "Apple 기기 연결 (identityservicesd)", "iMessage, FaceTime, 연속성 기능의 기기 연결."),
        E(.name("imagent"), "iMessage 송수신 (imagent)", "메시지 앱의 iMessage 송수신. 메시지 앱을 닫아도 돈다."),
        E(.name("sharingd"), "AirDrop과 핸드오프 (sharingd)", "AirDrop, 핸드오프, 근처 기기 공유."),
        E(.name("rapportd"), "기기 간 연결 (rapportd)", "연속성 카메라, 유니버설 컨트롤 같은 Apple 기기 간 연결."),
        E(.name("secd"), "키체인 (secd)", "키체인 접근. 끄면 금방 다시 켜진다."),
        E(.name("trustd"), "인증서 검사 (trustd)", "인증서 검사. 새 앱을 열거나 웹사이트에 접속할 때 잠깐 올라간다."),
        E(.name("cfprefsd"), "설정 파일 (cfprefsd)", "앱 설정 파일(.plist) 읽기와 쓰기 대행. 항상 작게 떠 있다."),
        E(.name("distnoted"), "알림 전달 (distnoted)", "앱 사이 알림 전달. 항상 작게 떠 있다."),
        E(.name("UserEventAgent"), "시스템 이벤트 (UserEventAgent)", "시스템 이벤트 처리. 항상 작게 떠 있다."),
        E(.name("lsd"), "앱 등록 정보 (lsd)", "앱 등록 정보(Launch Services) 관리."),
        E(.name("tccd"), "앱 권한 (tccd)", "카메라, 마이크 같은 앱 권한 관리."),
        E(.name("coreauthd"), "인증 (coreauthd)", "Touch ID와 암호 인증 창."),
        E(.name("MTLCompilerService"), "그래픽 셰이더 컴파일 (MTLCompilerService)", "그래픽 셰이더 컴파일. 게임이나 그래픽 앱을 켠 직후 올라가고 곧 내려간다."),
        E(.name("CalendarAgent"), "캘린더 동기화 (CalendarAgent)", "캘린더 동기화와 알림."),
        E(.name("appstoreagent"), "App Store 업데이트 (appstoreagent)", "App Store 앱 업데이트 다운로드. 끝나면 내려간다."),
        E(.name("commerce"), "App Store 결제 (commerce)", "App Store 결제와 업데이트 확인."),
        E(.name("storedownloadd"), "App Store 다운로드 (storedownloadd)", "App Store 다운로드. 끝나면 내려간다."),
        E(.name("ReportCrash"), "충돌 보고서 (ReportCrash)", "앱이 죽었을 때 보고서를 쓴다. 금방 끝난다."),
        E(.name("spindump"), "멈춤 진단 (spindump)", "앱이 멈췄을 때 진단 기록을 쓴다. 자주 보이면 멈추는 앱이 있다는 뜻이다."),
        E(.name("pboard"), "클립보드 (pboard)", "복사한 내용이 여기 있다. 큰 이미지를 복사하면 메모리가 늘어난다."),
        E(.name("talagent"), "창 복원 (talagent)", "로그인할 때 창을 복원한다."),
        E(.name("ViewBridgeAuxiliary"), "공유 UI (ViewBridgeAuxiliary)", "이모티콘 창처럼 앱 사이에서 공유하는 화면."),
        E(.name("com.apple.appkit.xpc.openAndSavePanelService"), "열기·저장 대화상자", "열기와 저장 대화상자. 창을 닫으면 내려간다."),
        E(.name("AMPLibraryAgent"), "음악·TV 보관함 (AMPLibraryAgent)", "음악과 TV 앱의 보관함 관리."),
        E(.name("AMPArtworkAgent"), "앨범 아트 (AMPArtworkAgent)", "음악과 TV 앱의 앨범 아트 처리."),
        E(.name("AMPDeviceDiscoveryAgent"), "근처 Apple 기기 검색", "Apple TV 같은 근처 기기 검색."),
        E(.name("deleted"), "저장 공간 정리 (deleted)", "휴지통 비우기 같은 저장 공간 자동 정리."),
        E(.name("dmd"), "방해 금지 모드 (dmd)", "집중 모드와 방해 금지 모드 관리."),
        E(.name("universalaccessd"), "손쉬운 사용 (universalaccessd)", "손쉬운 사용 기능."),
        E(.name("ScreenTimeAgent"), "스크린 타임 (ScreenTimeAgent)", "스크린 타임 사용 기록."),
        E(.name("CursorUIViewService"), "마우스 포인터 (CursorUIViewService)", "마우스 포인터 모양 그리기."),
        E(.name("com.apple.hiservices-xpcservice"), "키보드 단축키 서비스", "접근성과 키보드 단축키 서비스."),
        E(.name("gamed"), "Game Center (gamed)", "Game Center 연결."),
        E(.namePrefix("Wallpaper"), "배경화면", "동적·항공 배경화면을 그린다. 항공 배경화면은 메모리를 꽤 쓴다. 정지 사진으로 바꾸면 줄어든다."),
        E(.namePrefix("KoreanIM"), "한국어 입력기", "한국어 입력기. 글자를 입력할 때 쓴다."),
        E(.name("Electron"), "Electron 앱 일부", "Electron 기반 앱의 일부. 그 앱을 닫으면 사라진다."),
    ]

    /// 보통 root로 돌아 수치는 볼 수 없지만, 이름이 보일 때를 위해 둔다.
    private static let systemOnly: [CatalogEntry] = [
        E(.name("kernel_task"), "macOS 커널 (kernel_task)", "macOS 커널. CPU가 높아 보이면 대개 발열을 막으려고 일부러 CPU를 점유하는 것이다. 끌 수 없다.", protected: true),
        E(.name("WindowServer"), "화면 그리기 (WindowServer)", "모든 창을 화면에 그린다. 창이 많거나 외장 모니터를 쓰면 올라간다. 끌 수 없다.", protected: true),
        E(.name("launchd"), "프로세스 관리 (launchd)", "모든 프로세스의 부모. 끌 수 없다.", protected: true),
        E(.name("mds"), "Spotlight 서버 (mds)", "Spotlight 색인 서버.", protected: true),
        E(.name("mds_stores"), "Spotlight 색인 저장 (mds_stores)", "Spotlight 색인을 디스크에 쓴다. 새 파일이 많으면 한동안 바쁘다.", protected: true),
        E(.name("backupd"), "Time Machine (backupd)", "Time Machine 백업. 백업이 끝나면 내려간다.", protected: true),
        E(.name("softwareupdated"), "소프트웨어 업데이트 (softwareupdated)", "macOS 업데이트 확인과 다운로드.", protected: true),
        E(.name("syspolicyd"), "앱 보안 검사 (syspolicyd)", "Gatekeeper. 새 앱을 처음 열 때 검사한다.", protected: true),
        E(.name("XprotectService"), "악성 코드 검사 (XprotectService)", "macOS 내장 악성 코드 검사. 새 파일이 많으면 한동안 돈다.", protected: true),
        E(.name("coreaudiod"), "소리 (coreaudiod)", "모든 소리 입출력. 끌 수 없다.", protected: true),
        E(.name("opendirectoryd"), "계정 디렉터리 (opendirectoryd)", "사용자 계정과 그룹 조회.", protected: true),
        E(.name("runningboardd"), "프로세스 상태 관리 (runningboardd)", "앱의 실행 상태와 자원 관리.", protected: true),
        E(.name("logd"), "로그 (logd)", "시스템 로그 수집.", protected: true),
        E(.name("fseventsd"), "파일 변경 감시 (fseventsd)", "파일 변경 기록. Spotlight와 Time Machine이 쓴다.", protected: true),
        E(.name("locationd"), "위치 서비스 (locationd)", "위치 서비스.", protected: true),
        E(.name("bluetoothd"), "블루투스 (bluetoothd)", "블루투스 연결.", protected: true),
    ]

    /// 흔한 앱. 번들 ID로 맞춘다.
    private static let apps: [CatalogEntry] = [
        E(.bundleID("com.apple.Safari"), "Safari", "웹 브라우저. 웹 페이지 메모리는 'Safari 웹 페이지' 줄에 따로 보인다. 탭을 닫으면 줄어든다."),
        E(.bundleID("com.google.Chrome"), "Google Chrome", "웹 브라우저. 탭 하나가 프로세스 하나라 탭이 많으면 메모리를 많이 쓴다. 안 보는 탭을 닫으면 줄어든다."),
        E(.bundleID("org.mozilla.firefox"), "Firefox", "웹 브라우저. 탭이 많으면 메모리를 많이 쓴다."),
        E(.bundleID("com.microsoft.edgemac"), "Microsoft Edge", "웹 브라우저. 탭이 많으면 메모리를 많이 쓴다."),
        E(.bundleID("com.brave.Browser"), "Brave", "웹 브라우저. 탭이 많으면 메모리를 많이 쓴다."),
        E(.bundleID("com.naver.Whale"), "네이버 웨일", "웹 브라우저. 탭이 많으면 메모리를 많이 쓴다."),
        E(.bundleID("company.thebrowser.Browser"), "Arc", "웹 브라우저. 탭이 많으면 메모리를 많이 쓴다."),
        E(.bundleID("com.microsoft.VSCode"), "Visual Studio Code", "코드 편집기. 확장 프로그램과 언어 서버가 메모리를 많이 쓴다. 창을 줄이거나 확장을 끄면 줄어든다."),
        E(.bundleID("com.todesktop.230313mzl4w4u92"), "Cursor", "AI 코드 편집기. AI 기능과 확장 프로그램이 메모리를 많이 쓴다. 쓰지 않는 창을 닫으면 줄어든다."),
        E(.bundleID("com.apple.dt.Xcode"), "Xcode", "Apple 개발 도구. 색인과 빌드 중에 CPU를 많이 쓴다. 빌드가 끝나면 내려간다."),
        E(.bundleID("com.apple.iphonesimulator"), "시뮬레이터", "iOS 시뮬레이터. 켜 두면 기기 하나만큼 메모리를 쓴다. 안 쓰면 끄는 게 좋다."),
        E(.bundleID("com.apple.Terminal"), "터미널", "터미널. 여기서 띄운 명령(node, python 등)이 함께 묶여 있다. 끄면 그 명령들도 함께 꺼진다."),
        E(.bundleID("com.googlecode.iterm2"), "iTerm2", "터미널. 여기서 띄운 명령이 함께 묶여 있다. 끄면 그 명령들도 함께 꺼진다."),
        E(.bundleID("com.docker.docker"), "Docker Desktop", "컨테이너 실행 환경. 켜 두면 가상 머신이 메모리를 계속 잡는다. 컨테이너를 안 쓸 때는 끄는 게 좋다."),
        E(.bundleID("com.tinyspeck.slackmacgap"), "Slack", "메신저. 워크스페이스가 많으면 메모리를 많이 쓴다."),
        E(.bundleID("com.hnc.Discord"), "Discord", "메신저. 음성 채널에 있으면 CPU를 더 쓴다."),
        E(.bundleID("notion.id"), "Notion", "노트 앱. 페이지를 많이 열어 두면 메모리를 많이 쓴다."),
        E(.bundleID("com.kakao.KakaoTalkMac"), "카카오톡", "메신저. 사진과 동영상이 많은 채팅방을 열어 두면 메모리를 더 쓴다."),
        E(.bundleID("us.zoom.xos"), "Zoom", "화상 회의. 회의 중에는 CPU를 많이 쓴다. 회의가 끝나면 내려간다."),
        E(.bundleID("com.microsoft.teams2"), "Microsoft Teams", "화상 회의와 메신저. 회의 중에는 CPU를 많이 쓴다."),
        E(.bundleID("com.spotify.client"), "Spotify", "음악 스트리밍."),
        E(.bundleID("com.apple.Music"), "음악", "Apple 음악 앱."),
        E(.bundleID("com.figma.Desktop"), "Figma", "디자인 도구. 큰 파일을 열면 메모리를 많이 쓴다."),
        E(.bundleID("com.postmanlabs.mac"), "Postman", "API 테스트 도구."),
        E(.bundleID("com.jetbrains.intellij"), "IntelliJ IDEA", "개발 도구. 프로젝트 색인 중에 CPU를 많이 쓴다. 색인이 끝나면 내려간다."),
        E(.bundleID("com.jetbrains.intellij.ce"), "IntelliJ IDEA CE", "개발 도구. 프로젝트 색인 중에 CPU를 많이 쓴다."),
        E(.bundleID("com.jetbrains.pycharm"), "PyCharm", "파이썬 개발 도구. 색인 중에 CPU를 많이 쓴다."),
        E(.bundleID("com.jetbrains.WebStorm"), "WebStorm", "웹 개발 도구. 색인 중에 CPU를 많이 쓴다."),
        E(.bundleID("com.microsoft.Word"), "Word", "문서 편집기."),
        E(.bundleID("com.microsoft.Excel"), "Excel", "스프레드시트. 큰 파일을 열면 메모리를 많이 쓴다."),
        E(.bundleID("com.microsoft.Powerpoint"), "PowerPoint", "프레젠테이션 편집기."),
        E(.bundleID("com.adobe.Photoshop"), "Photoshop", "이미지 편집기. 큰 이미지를 열면 메모리를 많이 쓴다."),
        E(.bundleID("com.openai.chat"), "ChatGPT", "ChatGPT 데스크톱 앱."),
        E(.bundleID("com.anthropic.claudefordesktop"), "Claude", "Claude 데스크톱 앱."),
        E(.bundleID("com.1password.1password"), "1Password", "암호 관리자."),
        E(.bundleID("com.getdropbox.dropbox"), "Dropbox", "파일 동기화. 파일을 많이 바꾸면 한동안 바쁘다가 내려간다."),
        E(.bundleID("com.google.drivefs"), "Google Drive", "파일 동기화. 파일을 많이 바꾸면 한동안 바쁘다가 내려간다."),
        E(.bundleID("com.apple.Photos"), "사진", "사진 앱. 분석 작업은 '사진 분석' 줄에 따로 보인다."),
        E(.bundleID("com.apple.mail"), "Mail", "메일 앱. 처음 계정을 넣으면 메일을 받는 동안 바쁘다."),
        E(.bundleID("com.apple.Notes"), "메모", "메모 앱."),
        E(.bundleID("com.apple.iCal"), "캘린더", "캘린더 앱."),
        E(.bundleID("com.apple.Preview"), "미리보기", "PDF와 이미지 보기. 큰 파일을 열면 메모리를 많이 쓴다."),
        E(.bundleID("com.apple.ActivityMonitor"), "활성 상태 보기", "프로세스 모니터."),
        E(.bundleID("com.apple.TV"), "TV", "Apple TV 앱."),
        E(.bundleID("com.apple.MobileSMS"), "메시지", "메시지 앱."),
        E(.bundleID("com.apple.FaceTime"), "FaceTime", "영상 통화. 통화 중에는 CPU를 많이 쓴다."),
        E(.bundleID("com.apple.systempreferences"), "시스템 설정", "시스템 설정."),
        E(.bundleID("com.apple.AppStore"), "App Store", "App Store."),
        E(.bundleID("com.apple.iWork.Keynote"), "Keynote", "프레젠테이션 편집기."),
        E(.bundleID("com.apple.iWork.Pages"), "Pages", "문서 편집기."),
        E(.bundleID("com.apple.iWork.Numbers"), "Numbers", "스프레드시트."),
    ]

    /// 이름으로 뜨는 개발 도구와 서버.
    private static let devTools: [CatalogEntry] = [
        E(.name("node"), "Node.js (node)", "자바스크립트 실행기. 웹 개발 서버나 빌드 도구가 쓴다. 띄운 터미널이나 편집기를 닫으면 사라진다."),
        E(.name("Python"), "파이썬 (Python)", "파이썬 스크립트 실행 중. 띄운 터미널이나 편집기를 닫으면 사라진다."),
        E(.namePrefix("python"), "파이썬 (python)", "파이썬 스크립트 실행 중. 띄운 터미널이나 편집기를 닫으면 사라진다."),
        E(.name("java"), "자바 (java)", "자바 프로그램. IntelliJ, Gradle 같은 개발 도구가 많이 쓴다."),
        E(.name("ruby"), "루비 (ruby)", "루비 스크립트. Homebrew, CocoaPods 같은 도구가 쓴다."),
        E(.name("swift-frontend"), "Swift 컴파일 (swift-frontend)", "Swift 컴파일 중. 빌드가 끝나면 내려간다."),
        E(.namePrefix("clang"), "C 컴파일 (clang)", "C, C++, Objective-C 컴파일 중. 빌드가 끝나면 내려간다."),
        E(.name("SourceKitService"), "Xcode 코드 분석 (SourceKitService)", "Xcode의 코드 자동 완성과 분석. 큰 프로젝트에서는 메모리를 많이 쓴다. Xcode를 다시 켜면 비워진다."),
        E(.name("com.docker.backend"), "Docker 백엔드", "Docker Desktop의 백엔드."),
        E(.namePrefix("com.docker"), "Docker 가상 머신", "Docker 가상 머신. 컨테이너를 안 써도 설정한 메모리를 미리 잡는다. Docker Desktop을 끄면 비워진다."),
        E(.namePrefix("qemu-system"), "QEMU 가상 머신", "UTM, Colima 같은 도구의 가상 머신. 끄면 설정한 메모리가 비워진다."),
        E(.namePrefix("ollama"), "Ollama 로컬 AI (ollama)", "로컬 AI 모델 서버. 모델을 올려 두면 메모리를 수 GB 잡는다. 쓰지 않을 때 끄면 비워진다."),
        E(.namePrefix("gradle"), "Gradle 빌드 (gradle)", "Gradle 빌드 데몬. 빌드 뒤에도 몇 시간 남아 있다. 터미널에서 gradle --stop으로 끌 수 있다."),
        E(.name("rustc"), "Rust 컴파일 (rustc)", "Rust 컴파일 중. 빌드가 끝나면 내려간다."),
        E(.name("cargo"), "Rust 빌드 도구 (cargo)", "Rust 빌드 도구. 빌드가 끝나면 내려간다."),
        E(.name("go"), "Go (go)", "Go 빌드나 실행 중."),
        E(.name("zsh"), "셸 (zsh)", "터미널 명령 해석기. 터미널 창을 닫으면 사라진다."),
        E(.name("bash"), "셸 (bash)", "터미널 명령 해석기. 터미널 창을 닫으면 사라진다."),
        E(.name("ssh"), "원격 접속 (ssh)", "SSH 원격 접속 연결."),
        E(.name("ssh-agent"), "SSH 키 보관 (ssh-agent)", "SSH 키를 메모리에 보관한다. 항상 작게 떠 있다."),
        E(.name("git"), "Git (git)", "Git 명령 실행 중. 큰 저장소에서는 잠깐 CPU를 많이 쓴다."),
        E(.namePrefix("postgres"), "PostgreSQL (postgres)", "PostgreSQL 데이터베이스 서버."),
        E(.name("mysqld"), "MySQL (mysqld)", "MySQL 데이터베이스 서버."),
        E(.name("redis-server"), "Redis (redis-server)", "Redis 서버."),
        E(.name("mongod"), "MongoDB (mongod)", "MongoDB 서버."),
        E(.name("nginx"), "nginx", "nginx 웹 서버."),
        E(.name("limactl"), "Lima 가상 머신 (limactl)", "Colima, Lima 가상 머신 관리."),
        E(.name("containerd"), "컨테이너 런타임 (containerd)", "컨테이너 런타임."),
        E(.name("esbuild"), "esbuild", "자바스크립트 번들러. 빌드가 끝나면 내려간다."),
        E(.name("deno"), "Deno (deno)", "자바스크립트 실행기."),
        E(.name("bun"), "Bun (bun)", "자바스크립트 실행기."),
        E(.name("perl"), "펄 (perl)", "펄 스크립트 실행 중."),
        E(.name("php"), "PHP (php)", "PHP 스크립트 실행 중."),
    ]
}
```

- [ ] **Step 5: 통과 확인**

Run: `swift test 2>&1 | grep -E "error|warning:|✘|Test run with"; defaults delete com.cozynye.dallyeora.tests 2>/dev/null; true`
Expected: `✔ Test run with 64 tests in 12 suites passed`. 경고 없음.

- [ ] **Step 6: 커밋**

```bash
git add Sources/DallyeoraCore/Processes/ProcessCatalog.swift Sources/DallyeoraCore/Processes/CatalogEntries.swift Sources/DallyeoraCore/Processes/AppBundleInfo.swift Tests/DallyeoraCoreTests/ProcessCatalogTests.swift
git commit -m "feat: add Korean process catalog with fallbacks"
```

---

### Task 5: 프로세스 읽기

**Files:**
- Create: `Sources/DallyeoraCore/Processes/ProcessReader.swift`
- Test: `Tests/DallyeoraCoreTests/ProcessReaderTests.swift`

**Interfaces:**
- Consumes: `ProcessSample`, `ProcessSnapshot`
- Produces: `ProcessReader.snapshot() -> ProcessSnapshot`, `ProcessReader.nanos(_ machTime: UInt64) -> UInt64` (internal)

- [ ] **Step 1: 실패하는 테스트 작성**

`Tests/DallyeoraCoreTests/ProcessReaderTests.swift`:
```swift
import Darwin
import Testing
@testable import DallyeoraCore

struct ProcessReaderTests {
    @Test func readsOwnProcessesWithNumbersAndOthersWithout() {
        let snap = ProcessReader.snapshot()
        let me = getuid()
        let mine = snap.samples.filter { $0.uid == me }
        let others = snap.samples.filter { $0.uid != me }
        #expect(snap.uptime > 0)
        #expect(mine.contains { $0.pid == getpid() && $0.footprintBytes > 0 && $0.cpuTimeNanos > 0 })
        #expect(!others.isEmpty)
        #expect(others.allSatisfy { $0.footprintBytes == 0 && $0.cpuTimeNanos == 0 })
        #expect(snap.samples.allSatisfy { !$0.name.isEmpty && $0.pid > 0 })
        #expect(snap.samples.contains { $0.pid == 1 && $0.name == "launchd" && $0.path == "/sbin/launchd" })
    }

    @Test func namesComeFromTheLastPathComponent() {
        let snap = ProcessReader.snapshot()
        for s in snap.samples where !s.path.isEmpty {
            #expect(s.path.hasSuffix("/" + s.name), "\(s.pid) \(s.path) \(s.name)")
        }
    }

    @Test func nanosIsMonotonicAndZeroAtZero() {
        #expect(ProcessReader.nanos(0) == 0)
        #expect(ProcessReader.nanos(1_000) <= ProcessReader.nanos(2_000))
        #expect(ProcessReader.nanos(1_000_000) > 0)
    }
}
```

- [ ] **Step 2: 실패 확인**

Run: `swift test --filter ProcessReaderTests 2>&1 | grep -E "error:" | sort -u | head -3`
Expected: `cannot find 'ProcessReader' in scope`

- [ ] **Step 3: 구현**

`Sources/DallyeoraCore/Processes/ProcessReader.swift`:
```swift
import Darwin
import Foundation

/// libproc과 sysctl로 프로세스 목록을 읽는다. 사설 API는 쓰지 않는다.
/// 다른 사용자 소유 프로세스는 이름·경로·부모·uid만 읽히고 수치는 권한이 없어 0이다.
public enum ProcessReader {
    public static func snapshot() -> ProcessSnapshot {
        let me = getuid()
        let uptime = ProcessInfo.processInfo.systemUptime
        var count = proc_listallpids(nil, 0)
        guard count > 0 else { return ProcessSnapshot(uptime: uptime, samples: []) }
        var pids = [pid_t](repeating: 0, count: Int(count) + 64)
        count = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size))

        var samples: [ProcessSample] = []
        samples.reserveCapacity(Int(count))
        for pid in pids.prefix(Int(max(count, 0))) where pid > 0 {
            guard let info = kinfo(pid) else { continue } // 목록을 받은 뒤 끝난 프로세스
            let path = self.path(of: pid)
            let name = path.isEmpty ? info.comm : (path as NSString).lastPathComponent
            var footprint: UInt64 = 0
            var cpu: UInt64 = 0
            if info.uid == me, let usage = rusage(pid) {
                footprint = usage.ri_phys_footprint
                cpu = nanos(usage.ri_user_time + usage.ri_system_time)
            }
            samples.append(ProcessSample(pid: pid, ppid: info.ppid, uid: info.uid, name: name, path: path,
                                         footprintBytes: footprint, cpuTimeNanos: cpu))
        }
        return ProcessSnapshot(uptime: uptime, samples: samples)
    }

    private struct KInfo {
        var ppid: pid_t
        var uid: uid_t
        var comm: String
    }

    private static func kinfo(_ pid: pid_t) -> KInfo? {
        var kp = kinfo_proc()
        var len = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        guard sysctl(&mib, 4, &kp, &len, nil, 0) == 0, len > 0 else { return nil }
        let comm = withUnsafePointer(to: &kp.kp_proc.p_comm) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXCOMLEN) + 1) { String(cString: $0) }
        }
        return KInfo(ppid: kp.kp_eproc.e_ppid, uid: kp.kp_eproc.e_ucred.cr_uid, comm: comm)
    }

    private static func path(of pid: pid_t) -> String {
        var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        return length > 0 ? String(cString: buffer) : ""
    }

    private static func rusage(_ pid: pid_t) -> rusage_info_v4? {
        var info = rusage_info_v4()
        // proc_pid_rusage는 rusage_info_t*(void**)를 받지만 실제로는 구조체 메모리 자체를 가리켜야 한다.
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_V4, $0)
            }
        }
        return result == 0 ? info : nil
    }

    private static let timebase: (numer: UInt64, denom: UInt64) = {
        var info = mach_timebase_info()
        mach_timebase_info(&info)
        return (UInt64(info.numer), UInt64(info.denom))
    }()

    /// Mach 시간 단위를 나노초로.
    static func nanos(_ machTime: UInt64) -> UInt64 {
        machTime * timebase.numer / timebase.denom
    }
}
```

- [ ] **Step 4: 통과 확인**

Run: `swift test 2>&1 | grep -E "error|warning:|✘|Test run with"; defaults delete com.cozynye.dallyeora.tests 2>/dev/null; true`
Expected: `✔ Test run with 67 tests in 13 suites passed`. 경고 없음. `namesComeFromTheLastPathComponent`가 실패하면 실패한 pid와 경로를 읽고 원인을 찾는다(심볼릭 링크 등). 테스트를 느슨하게 고치지 않는다.

- [ ] **Step 5: 커밋**

```bash
git add Sources/DallyeoraCore/Processes/ProcessReader.swift Tests/DallyeoraCoreTests/ProcessReaderTests.swift
git commit -m "feat: read process list and usage through libproc"
```

---

### Task 6: 종료 담당과 화면 모델

**Files:**
- Create: `Sources/Dallyeora/Cleanup/AppTerminator.swift`
- Create: `Sources/Dallyeora/Cleanup/CleanupModel.swift`

**Interfaces:**
- Consumes: `ProcessReader`, `ProcessGrouper`, `UsageRanker`, `ProcessCatalog`, `AppBundleInfo`, `UsageFormat`, `CPUTicks`, `CPUUsage`, `MemoryPages`, `MemoryUsage`, `Metric`
- Produces: `CleanupModel(metric:)`, `CleanupModel.Row` (`id`, `title`, `summary`, `icon: NSImage?`, `usageText`, `badge: Badge { .quittable, .background, .system, .others }`, `mainPID`, `quitState: QuitState { .idle, .requested, .force }`), `CleanupModel.metric`, `.rows`, `.totalText`, `.failed`, `.start()`, `.stop()`, `.quit(_ row:)`, `.forceQuit(_ row:)`, `.appName(of row:)`

AppKit 코드라 단위 테스트는 없다. 이 태스크의 검증은 경고 없는 빌드다.

- [ ] **Step 1: AppTerminator**

`Sources/Dallyeora/Cleanup/AppTerminator.swift`:
```swift
import AppKit

/// NSRunningApplication 감싸기. 스펙 3.7의 종료 가능 판정과 종료 명령.
@MainActor
struct AppTerminator {
    func application(_ pid: pid_t) -> NSRunningApplication? {
        NSRunningApplication(processIdentifier: pid)
    }

    /// Dock이나 메뉴 막대에 보이는 앱만.
    func canQuit(_ pid: pid_t) -> Bool {
        guard let app = application(pid) else { return false }
        return app.activationPolicy != .prohibited
    }

    /// ⌘Q와 같다. 저장하지 않은 문서가 있으면 그 앱이 묻는다. 요청을 보냈으면 true.
    func quit(_ pid: pid_t) -> Bool {
        application(pid)?.terminate() ?? false
    }

    func forceQuit(_ pid: pid_t) -> Bool {
        application(pid)?.forceTerminate() ?? false
    }

    func isRunning(_ pid: pid_t) -> Bool {
        kill(pid, 0) == 0
    }

    func icon(forBundleAt path: String) -> NSImage {
        NSWorkspace.shared.icon(forFile: path)
    }
}
```

- [ ] **Step 2: CleanupModel**

`Sources/Dallyeora/Cleanup/CleanupModel.swift`:
```swift
import AppKit
import DallyeoraCore
import Observation

/// 스냅샷 → 묶기 → 순위 → 설명을 이어 화면용 행을 만든다. 창이 보이는 동안만 돈다.
@MainActor
@Observable
final class CleanupModel {
    struct Row: Identifiable {
        enum Badge { case quittable, background, system, others }
        enum QuitState { case idle, requested, force }

        let id: String
        let title: String
        let summary: String
        let icon: NSImage?
        let usageText: String
        let badge: Badge
        let mainPID: pid_t?
        let quitState: QuitState
    }

    var metric: Metric {
        didSet { rebuild() }
    }
    private(set) var rows: [Row] = []
    private(set) var totalText = ""
    private(set) var failed = false

    private let terminator = AppTerminator()
    private var previous: ProcessSnapshot?
    private var current: ProcessSnapshot?
    private var lastTicks: CPUTicks?
    private var totalCPU: Double?
    private var memoryPercent: Double = 0
    private var memoryBytes: UInt64 = 0
    private var quitStates: [String: Row.QuitState] = [:]
    private var timer: Timer?

    init(metric: Metric) {
        self.metric = metric
    }

    // MARK: 갱신

    /// 바로 한 번 읽고, 1초 뒤 한 번 더 읽어 CPU 값을 빨리 채운 뒤 2초마다 돈다.
    func start() {
        refresh()
        schedule(after: 1)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func schedule(after interval: TimeInterval) {
        timer?.invalidate()
        let timer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh()
                self?.schedule(after: 2)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func refresh() {
        let snapshot = ProcessReader.snapshot()
        guard !snapshot.samples.isEmpty else {
            failed = true
            return
        }
        failed = false
        if let ticks = CPUTicks.current() {
            if let last = lastTicks { totalCPU = CPUUsage.percent(from: last, to: ticks) }
            lastTicks = ticks
        }
        if let pages = MemoryPages.current() {
            memoryPercent = MemoryUsage.percent(pages)
            memoryBytes = MemoryUsage.usedBytes(pages)
        }
        previous = current
        current = snapshot
        rebuild()
    }

    private func rebuild() {
        guard let current else { return }
        let groups = ProcessGrouper.group(current, currentUID: getuid(), selfPID: getpid())
        let ranked = UsageRanker.rank(
            groups: groups, current: current, previous: previous,
            cpuCount: ProcessInfo.processInfo.activeProcessorCount,
            totals: .init(cpuPercent: totalCPU, memoryBytes: memoryBytes), metric: metric)
        rows = ranked.map(makeRow)
        let liveIDs = Set(rows.map(\.id))
        quitStates = quitStates.filter { liveIDs.contains($0.key) }
        let total = metric == .cpu ? (totalCPU.map(UsageFormat.percent) ?? "측정 중…") : UsageFormat.percent(memoryPercent)
        totalText = "지금 \(metric.label)를 많이 쓰는 것 · 전체 \(total)"
    }

    private func makeRow(_ ranked: RankedRow) -> Row {
        let usage = metric == .cpu
            ? (ranked.cpuPercent.map(UsageFormat.percent) ?? "측정 중…")
            : UsageFormat.bytes(ranked.memoryBytes)

        guard let group = ranked.group else {
            return Row(id: "others", title: "그 외 \(ranked.count)개", summary: "15위 밖의 묶음을 합친 값이다.",
                       icon: nil, usageText: usage, badge: .others, mainPID: nil, quitState: .idle)
        }

        if case .app(let bundle, let mainPID) = group.kind {
            let description = ProcessCatalog.describe(
                group, bundleID: AppBundleInfo.bundleID(at: bundle), localizedName: AppBundleInfo.displayName(at: bundle))
            let badge: Row.Badge = description.isProtected ? .system : (terminator.canQuit(mainPID) ? .quittable : .background)
            return Row(id: group.id, title: description.title, summary: description.summary,
                       icon: terminator.icon(forBundleAt: bundle), usageText: usage, badge: badge,
                       mainPID: mainPID, quitState: quitStates[group.id] ?? .idle)
        }

        let description = ProcessCatalog.describe(group, bundleID: nil, localizedName: nil)
        let badge: Row.Badge = ranked.kind == .system ? .system : .background
        let title = ranked.kind == .background && ranked.count > 1 ? "\(description.title) ×\(ranked.count)" : description.title
        return Row(id: group.id, title: title, summary: description.summary, icon: nil, usageText: usage,
                   badge: badge, mainPID: nil, quitState: .idle)
    }

    // MARK: 종료

    func appName(of row: Row) -> String {
        row.title
    }

    /// 일반 종료. 5초 뒤에도 살아 있으면 강제 종료 버튼으로 바뀐다.
    func quit(_ row: Row) {
        guard let pid = row.mainPID else { return }
        let id = row.id // Timer 블록은 @Sendable이라 Row(NSImage 포함)를 잡지 않고 값만 잡는다
        let sent = terminator.quit(pid)
        quitStates[id] = sent ? .requested : .force
        rebuild()
        guard sent else { return }
        let check = Timer(timeInterval: 5, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.quitStates[id] = self.terminator.isRunning(pid) ? .force : nil
                self.rebuild()
            }
        }
        RunLoop.main.add(check, forMode: .common)
    }

    func forceQuit(_ row: Row) {
        guard let pid = row.mainPID else { return }
        _ = terminator.forceQuit(pid)
        quitStates[row.id] = nil
        rebuild()
    }
}
```

- [ ] **Step 3: 빌드 확인**

Run: `swift build 2>&1 | grep -E "error|warning:|Build complete"`
Expected: `Build complete!` 한 줄만. `Observation`과 `@Observable`은 macOS 14부터라 그대로 컴파일된다.

- [ ] **Step 4: 커밋**

```bash
git add Sources/Dallyeora/Cleanup/AppTerminator.swift Sources/Dallyeora/Cleanup/CleanupModel.swift
git commit -m "feat: add cleanup model that ranks apps and quits them"
```

---

### Task 7: 창과 메뉴 항목

**Files:**
- Create: `Sources/Dallyeora/Cleanup/CleanupView.swift`
- Create: `Sources/Dallyeora/Cleanup/CleanupWindowController.swift`
- Modify: `Sources/Dallyeora/StatusItemController.swift`

**Interfaces:**
- Consumes: `CleanupModel` (Task 6), `Settings.metric`
- Produces: `CleanupWindowController.show(metric:)`, 메뉴 항목 "정리하기…"

- [ ] **Step 1: CleanupView**

`Sources/Dallyeora/Cleanup/CleanupView.swift`:
```swift
import DallyeoraCore
import SwiftUI

struct CleanupView: View {
    @Bindable var model: CleanupModel
    /// 강제 종료 확인 창은 AppKit NSAlert로 띄운다(SwiftUI alert보다 메뉴 막대 앱에서 안정적).
    let confirmForceQuit: (CleanupModel.Row) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("지표", selection: $model.metric) {
                ForEach(Metric.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 180)

            Text(model.totalText).font(.headline)

            if model.failed {
                Spacer()
                Text("프로세스 정보를 읽을 수 없습니다").frame(maxWidth: .infinity)
                Spacer()
            } else {
                List(model.rows) { row in
                    RowView(row: row, quit: { model.quit(row) }, forceQuit: { confirmForceQuit(row) })
                        .listRowSeparator(.visible)
                }
                .listStyle(.inset)
            }
        }
        .padding()
        .frame(minWidth: 480, minHeight: 360)
    }
}

private struct RowView: View {
    let row: CleanupModel.Row
    let quit: () -> Void
    let forceQuit: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            iconView.frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.title).font(.body.weight(.semibold))
                Text(row.summary).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Text(row.usageText).font(.body.monospacedDigit()).frame(minWidth: 72, alignment: .trailing)
            badge.frame(width: 92)
            quitButton.frame(width: 84)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder private var iconView: some View {
        if let icon = row.icon {
            Image(nsImage: icon).resizable()
        } else {
            Image(systemName: "gearshape").resizable().scaledToFit().foregroundStyle(.secondary).padding(5)
        }
    }

    private var badge: some View {
        let (text, color): (String, Color) = switch row.badge {
        case .quittable: ("끌 수 있음", .green)
        case .background: ("내 백그라운드", .gray)
        case .system: ("시스템", .orange)
        case .others: ("그 외", .gray)
        }
        return Text(text).font(.caption2).padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule()).foregroundStyle(color)
    }

    @ViewBuilder private var quitButton: some View {
        if row.badge == .quittable {
            switch row.quitState {
            case .idle: Button("종료", action: quit)
            case .requested: Button("종료 중…") {}.disabled(true)
            case .force: Button("강제 종료", role: .destructive, action: forceQuit)
            }
        }
    }
}
```

- [ ] **Step 2: CleanupWindowController**

`Sources/Dallyeora/Cleanup/CleanupWindowController.swift`:
```swift
import AppKit
import DallyeoraCore
import SwiftUI

/// 창은 하나만 만들고 재사용한다. 닫으면 타이머를 멈추고, 다시 열면 메뉴 막대 지표로 시작한다.
@MainActor
final class CleanupWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var model: CleanupModel?

    func show(metric: Metric) {
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }
        let model = self.model ?? CleanupModel(metric: metric)
        model.metric = metric
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 560, height: 440),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered, defer: false)
            window.title = "정리하기"
            window.minSize = NSSize(width: 480, height: 360)
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.contentView = NSHostingView(rootView: CleanupView(model: model) { [weak self] row in
                self?.confirmForceQuit(row, model: model)
            })
            window.center()
            self.window = window
        }
        self.model = model
        model.start()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func windowWillClose(_ notification: Notification) {
        model?.stop()
    }

    /// 강제 종료는 저장하지 않은 작업을 잃을 수 있어 한 번 묻는다.
    private func confirmForceQuit(_ row: CleanupModel.Row, model: CleanupModel) {
        let alert = NSAlert()
        alert.messageText = "\"\(model.appName(of: row))\"을(를) 강제 종료할까요?"
        alert.informativeText = "저장하지 않은 작업은 사라집니다."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "강제 종료")
        alert.addButton(withTitle: "취소")
        if alert.runModal() == .alertFirstButtonReturn {
            model.forceQuit(row)
        }
    }
}
```

- [ ] **Step 3: 메뉴 항목**

`Sources/Dallyeora/StatusItemController.swift` 수정. 프로퍼티 추가:
```swift
    private let cleanup = CleanupWindowController()
```
`buildMenu()`에서 `menu.addItem(phraseItem)` 다음의 `menu.addItem(.separator())` 바로 뒤에 추가:
```swift
        let cleanupItem = NSMenuItem(title: "정리하기…", action: #selector(openCleanup), keyEquivalent: "")
        cleanupItem.target = self
        menu.addItem(cleanupItem)
        menu.addItem(.separator())
```
클래스 끝에 추가:
```swift
    @objc private func openCleanup() {
        cleanup.show(metric: settings.metric)
    }
```

- [ ] **Step 4: 빌드와 테스트**

Run: `swift build 2>&1 | grep -E "error|warning:|Build complete"; swift test 2>&1 | grep -E "✘|Test run with"; defaults delete com.cozynye.dallyeora.tests 2>/dev/null; true`
Expected: `Build complete!`, `✔ Test run with 67 tests in 13 suites passed`. 경고가 나오면(특히 `NSApp.activate()` 관련) 고치고 넘어간다.

- [ ] **Step 5: 실행해서 확인**

Run: `pkill -x Dallyeora; swift run Dallyeora &` 뒤 메뉴 막대에서 "정리하기…"를 누른다.
확인(화면 캡처 권한이 없어 사용자가 본다. 아래 항목을 보고에 그대로 적는다):
1. 창이 다른 앱 위로 뜨고 제목이 "정리하기"다. 뜨지 않으면 `NSApp.activate()`를 `NSApp.activate(ignoringOtherApps: true)`로 바꾸고 경고 유무를 다시 본다.
2. 세그먼트가 메뉴 막대 지표와 같은 쪽에 있다.
3. 요약 줄에 "지금 … 많이 쓰는 것 · 전체 N%"가 보이고 2초마다 숫자가 바뀐다.
4. 크롬·Cursor 같은 앱이 한 줄로 묶여 있고, 아이콘·한국어 설명·"끌 수 있음" 배지·종료 버튼이 있다.
5. "macOS 시스템" 줄이 있고 설명에 프로세스 개수가 있다.
6. CPU 탭에서 첫 1초는 "측정 중…"이다가 숫자로 바뀐다.
7. 저장할 것 없는 앱(예: 계산기)을 켜고 종료를 누르면 꺼지고 다음 갱신 때 줄이 사라진다. **macOS 권한 요청 창이 뜨는지 본다**(뜨면 보고에 적는다).
8. 저장하지 않은 문서가 있는 앱(예: 텍스트 편집기에 글자 입력)에 종료를 누르면 그 앱이 저장 여부를 묻고, 5초 뒤 버튼이 "강제 종료"로 바뀐다. 강제 종료를 누르면 확인 창이 뜨고, 취소하면 아무 일도 없다.
9. 창을 닫고 메뉴 막대 지표를 바꾼 뒤 다시 열면 세그먼트가 바뀐 지표다.
10. Finder 줄이 있으면 배지가 "시스템"이고 버튼이 없다.

- [ ] **Step 6: 커밋**

```bash
git add Sources/Dallyeora/Cleanup/CleanupView.swift Sources/Dallyeora/Cleanup/CleanupWindowController.swift Sources/Dallyeora/StatusItemController.swift
git commit -m "feat: add cleanup window that lists and quits heavy apps"
```

---

### Task 8: 문서, 빌드, README 초안

**Files:**
- Modify: `CLAUDE.md`
- Modify: `README.md`, `README.en.md` (커밋하지 않음)

- [ ] **Step 1: CLAUDE.md**

구조 줄 뒤에 추가:
```
- `Sources/DallyeoraCore/Processes`: 프로세스 읽기·묶기·순위·사전. 사전 항목은 `CatalogEntries.swift`에 추가하고 `ProcessCatalogTests.catalogCoversTheRequiredNames`의 목록을 함께 갱신한다.
- `Sources/Dallyeora/Cleanup`: 정리하기 창(SwiftUI를 NSHostingView로).
```
설계 줄을 `설계: docs/spec.md, docs/spec-cleanup.md`로 바꾼다.

- [ ] **Step 2: 커밋**

```bash
git add CLAUDE.md
git commit -m "docs: describe the cleanup modules"
```

- [ ] **Step 3: README 초안 (커밋하지 않는다)**

`README.md`의 "## 설치" 앞에 절을 추가한다. 평서체, 중립적 설명체, 1인칭 없이:
```
## 정리하기

메뉴의 "정리하기…"를 누르면 지금 CPU나 메모리를 많이 쓰는 것을 사용량 순으로 보여 주는 창이 뜬다. 크롬처럼 보조 프로세스가 수십 개인 앱은 한 줄로 묶이고, 각 줄에는 한국어 이름과 왜 올라가는지, 기다리면 내려가는지에 대한 한 줄 설명이 붙는다. Dock이나 메뉴 막대에 보이는 앱에는 종료 버튼이 있어 ⌘Q를 누른 것과 같이 끌 수 있고, 5초가 지나도 꺼지지 않으면 강제 종료 버튼으로 바뀐다.

시스템 프로세스는 관리자 권한 없이 수치를 읽을 수 없어 "macOS 시스템" 한 줄로 합쳐 보이고, 메모리 합계는 메뉴 막대의 사용률과 기준이 달라 정확히 맞지 않는다. 사전에 없는 프로세스는 이름 그대로 또는 "알 수 없음"으로 보이며, 사전은 `Sources/DallyeoraCore/Processes/CatalogEntries.swift`에서 늘릴 수 있다.
```
`README.en.md`의 "## Install" 앞에 같은 내용을 영어로 추가한다:
```
## Cleanup window

Choosing "정리하기…" (Clean up) from the menu opens a window that lists what is using the most CPU or memory right now. Apps with dozens of helper processes, like Chrome, are collapsed into one row, and each row carries a Korean name and a one-line note on why it is busy and whether it will settle down on its own. Apps that appear in the Dock or menu bar get a Quit button that works like ⌘Q; if the app is still running after five seconds the button changes to Force Quit, which asks for confirmation first.

System processes cannot be measured without administrator rights, so they appear as a single "macOS 시스템" row, and the memory total does not match the menu bar percentage exactly because the two use different definitions. Processes not in the built-in catalog show their raw name or "unknown"; the catalog lives in `Sources/DallyeoraCore/Processes/CatalogEntries.swift`.
```
"## 설치"의 두 번째 문단도 고친다. macOS 15부터는 우클릭 → 열기가 공증 없는 앱에 통하지 않는다(사용자가 v0.3.0 dmg로 실제 겪음):
```
Apple 공증을 받지 않은 앱이라 처음 열 때 "악성 코드가 없음을 확인할 수 없습니다"라는 창이 뜨고 열리지 않는다. 그 창을 닫은 뒤 시스템 설정 → 개인정보 보호 및 보안으로 가서 아래쪽에 뜨는 "그래도 열기"를 누르고, 다시 앱을 열어 확인하면 된다. 이 버튼은 막힌 뒤 한 시간 동안만 보인다. 터미널이 편하면 `xattr -d com.apple.quarantine /Applications/Dallyeora.app`으로 격리 표시를 지워도 된다. 한 번 열고 나면 다음부터는 그냥 실행된다.
```
영어 README의 같은 문단도 맞춰 고친다:
```
Because the app isn't notarized by Apple, the first launch is blocked with a message saying Apple could not verify it is free of malware. Close that dialog, open System Settings > Privacy & Security, scroll down and click "Open Anyway", then open the app again and confirm. The button is only shown for about an hour after the blocked attempt. If you prefer the terminal, `xattr -d com.apple.quarantine /Applications/Dallyeora.app` removes the quarantine flag instead. After the first launch it opens normally.
```
"## 한계" / "## Known limitations"에도 한 문장씩 보탠다: `정리하기 창은 한국어만 지원하고 시스템 프로세스는 개별로 보이지 않는다.` / `The cleanup window is Korean only and does not list system processes individually.`

- [ ] **Step 4: 빌드해서 띄우기**

Run: `pkill -x Dallyeora; scripts/make-app.sh 0.4.0 2>&1 | tail -1; open dist/Dallyeora.app`
Expected: `dist/Dallyeora-0.4.0.dmg`. 앱이 메뉴 막대에 뜬다.

- [ ] **Step 5: 보고**

사용자에게 `git diff README.md README.en.md`를 보여 주고 커밋·push·Release 허락을 받는다. Task 7 Step 5의 확인 항목 10개와, 권한 요청 창 유무(미검증)를 함께 적는다.
