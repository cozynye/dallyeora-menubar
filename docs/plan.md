# 달려라 메뉴바 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** CPU 사용률에 따라 한국 밈 캐릭터(기본: 개복치)가 움직이고 문구가 바뀌는 macOS 메뉴 막대 앱을 만든다.

**Architecture:** Swift Package 하나에 두 타깃. `DallyeoraCore`(AppKit 없음: CPU 계산, 단계 선택, 프레임 간격, 캐릭터 그리기, 설정)는 단위 테스트로 검증하고, `Dallyeora`(AppKit 실행 파일)는 `NSStatusItem`에 Core가 그린 이미지와 문구를 붙인다.

**Tech Stack:** Swift 6.3 (Swift 6 language mode), SwiftPM, AppKit, Core Graphics, Swift Testing, Xcode 26.6, macOS 14+

**Spec:** `docs/spec.md`

## Global Constraints

- 최소 macOS 14 (`platforms: [.macOS(.v14)]`), Swift tools 6.0, 외부 의존성 없음
- 프로젝트 루트: `/Users/sinsunyeong/Desktop/playground/projects/dallyeora-menubar` (아래 모든 경로는 여기 기준)
- 기본 캐릭터 `sunfish`(개복치), 기본 말투 `standard`(표준어)
- 캐릭터 순서: sunfish, worker, pork, rider
- 프레임 간격 = `0.2 - (cpu / 100) × 0.17`초, phase 증가량 0.6, CPU 측정 주기 2초
- 그림 좌표: 28×18pt, y축 아래 방향, 단색. 앱에서는 template 이미지로 표시
- 문구는 spec 3.3 표를 글자 그대로 사용
- 커밋은 사용자가 요청할 때만 한다 (전역 CLAUDE.md 규칙). 각 Task의 마지막 단계는 "커밋 지점"이고, 사용자가 커밋하기로 했으면 그때 커밋한다.

## Review Focus

1. CPU tick 카운터가 줄어들거나(32비트 wrap) 변화가 없을 때 → 0%로 처리하고 음수나 크래시가 없어야 한다. (Task 1 테스트)
2. CPU 값이 NaN, 음수, 100 초과일 때 → 단계 선택과 그리기에서 크래시 없이 0–100으로 제한된다. `Int(.nan)`은 크래시이므로 중요하다. (Task 1, 2 테스트)
3. 저장된 캐릭터 id나 말투 값이 알 수 없는 값일 때(예: 이후 버전에서 이름 변경) → 개복치/표준어로 돌아간다. (Task 3 테스트)
4. 드롭다운 메뉴가 열려 있는 동안 → 애니메이션과 CPU %가 계속 갱신된다. 타이머를 `.common` run loop mode에 등록해야 한다. (Task 4 수동 확인)
5. 다크 모드 / 라이트 모드 전환 → 아이콘이 template 이미지라서 두 모드 모두 보인다. (Task 4 수동 확인)

---

## File Structure

```
dallyeora-menubar/
├── Package.swift
├── CLAUDE.md
├── README.md
├── LICENSE
├── .gitignore
├── docs/spec.md, docs/plan.md
├── scripts/make-app.sh
├── Sources/
│   ├── DallyeoraCore/
│   │   ├── CPUUsage.swift        # CPUTicks, CPUUsage.percent / clamp, CPUTicks.current()
│   │   ├── AnimationClock.swift  # frameInterval(cpu:), phaseStep
│   │   ├── Mascot.swift          # Tone, Tier, Mascot 프로토콜, Mascots 레지스트리
│   │   ├── Drawing.swift         # CGContext 그리기 헬퍼 + MascotRenderer
│   │   ├── Settings.swift        # UserDefaults 저장
│   │   └── Mascots/
│   │       ├── Sunfish.swift
│   │       ├── Worker.swift
│   │       ├── Pork.swift
│   │       └── Rider.swift
│   └── Dallyeora/
│       ├── main.swift
│       ├── AppDelegate.swift
│       └── StatusItemController.swift
└── Tests/DallyeoraCoreTests/
    ├── CPUUsageTests.swift
    ├── AnimationClockTests.swift
    ├── MascotTests.swift
    ├── RenderTests.swift
    └── SettingsTests.swift
```

---

### Task 1: 패키지 뼈대 + CPU 계산 + 프레임 간격

**Files:**
- Create: `Package.swift`, `.gitignore`, `Sources/DallyeoraCore/CPUUsage.swift`, `Sources/DallyeoraCore/AnimationClock.swift`, `Sources/Dallyeora/main.swift`(임시 최소본)
- Test: `Tests/DallyeoraCoreTests/CPUUsageTests.swift`, `Tests/DallyeoraCoreTests/AnimationClockTests.swift`

**Interfaces:**
- Produces:
  - `public struct CPUTicks: Equatable, Sendable { user, system, idle, nice: UInt64; busy: UInt64; total: UInt64; static func current() -> CPUTicks? }`
  - `public enum CPUUsage { static func percent(from: CPUTicks, to: CPUTicks) -> Double; static func clamp(_ cpu: Double) -> Double }`
  - `public enum AnimationClock { static let phaseStep: Double; static func frameInterval(cpu: Double) -> TimeInterval }`

- [ ] **Step 1: git 저장소와 패키지 매니페스트 생성**

```bash
cd /Users/sinsunyeong/Desktop/playground/projects/dallyeora-menubar
git init -b main
git config user.email   # cozynye@gmail.com 이어야 함
```

`Package.swift`:
```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Dallyeora",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "DallyeoraCore"),
        .executableTarget(name: "Dallyeora", dependencies: ["DallyeoraCore"]),
        .testTarget(name: "DallyeoraCoreTests", dependencies: ["DallyeoraCore"]),
    ]
)
```

`.gitignore`:
```
.build/
.swiftpm/
dist/
.DS_Store
```

`Sources/Dallyeora/main.swift` (Task 4에서 교체):
```swift
import DallyeoraCore
```

- [ ] **Step 2: 실패하는 테스트 작성**

`Tests/DallyeoraCoreTests/CPUUsageTests.swift`:
```swift
import Testing
@testable import DallyeoraCore

struct CPUUsageTests {
    @Test func computesBusyShareOfDelta() {
        let a = CPUTicks(user: 100, system: 50, idle: 800, nice: 50)
        let b = CPUTicks(user: 130, system: 60, idle: 850, nice: 60)
        // busy Δ = 30 + 10 + 10 = 50, total Δ = 50 + 50 = 100
        #expect(CPUUsage.percent(from: a, to: b) == 50)
    }

    @Test func allBusyIsHundred() {
        let a = CPUTicks(user: 0, system: 0, idle: 0, nice: 0)
        let b = CPUTicks(user: 50, system: 50, idle: 0, nice: 0)
        #expect(CPUUsage.percent(from: a, to: b) == 100)
    }

    @Test func noChangeIsZero() {
        let a = CPUTicks(user: 10, system: 10, idle: 10, nice: 10)
        #expect(CPUUsage.percent(from: a, to: a) == 0)
    }

    @Test func counterWrapIsZero() {
        let a = CPUTicks(user: 4_000_000_000, system: 0, idle: 0, nice: 0)
        let b = CPUTicks(user: 10, system: 0, idle: 20, nice: 0)
        #expect(CPUUsage.percent(from: a, to: b) == 0)
    }

    @Test(arguments: [(-5.0, 0.0), (150.0, 100.0), (.nan, 0.0), (.infinity, 0.0), (42.0, 42.0)])
    func clampKeepsRange(input: Double, expected: Double) {
        #expect(CPUUsage.clamp(input) == expected)
    }

    @Test func readsLiveTicks() {
        let ticks = CPUTicks.current()
        #expect(ticks != nil)
        #expect((ticks?.total ?? 0) > 0)
    }
}
```

`Tests/DallyeoraCoreTests/AnimationClockTests.swift`:
```swift
import Testing
@testable import DallyeoraCore

struct AnimationClockTests {
    @Test(arguments: [(0.0, 0.2), (100.0, 0.03), (50.0, 0.115), (-10.0, 0.2), (150.0, 0.03), (.nan, 0.2)])
    func frameIntervalShrinksWithCPU(cpu: Double, expected: Double) {
        #expect(abs(AnimationClock.frameInterval(cpu: cpu) - expected) < 1e-9)
    }
}
```

- [ ] **Step 3: 실패 확인**

Run: `swift test`
Expected: 컴파일 실패 — `cannot find 'CPUTicks' in scope`

- [ ] **Step 4: 구현**

`Sources/DallyeoraCore/CPUUsage.swift`:
```swift
import Darwin

public struct CPUTicks: Equatable, Sendable {
    public var user: UInt64
    public var system: UInt64
    public var idle: UInt64
    public var nice: UInt64

    public init(user: UInt64, system: UInt64, idle: UInt64, nice: UInt64) {
        self.user = user
        self.system = system
        self.idle = idle
        self.nice = nice
    }

    public var busy: UInt64 { user + system + nice }
    public var total: UInt64 { busy + idle }
}

public enum CPUUsage {
    /// 두 측정 사이의 사용률(0–100). 카운터가 줄었거나 변화가 없으면 0.
    public static func percent(from old: CPUTicks, to new: CPUTicks) -> Double {
        guard new.total > old.total, new.busy >= old.busy else { return 0 }
        let busy = Double(new.busy - old.busy)
        let total = Double(new.total - old.total)
        return clamp(busy / total * 100)
    }

    /// NaN·무한대는 0, 나머지는 0–100으로 제한.
    public static func clamp(_ cpu: Double) -> Double {
        cpu.isFinite ? min(100, max(0, cpu)) : 0
    }
}

private let hostPort = mach_host_self()

extension CPUTicks {
    /// 전체 코어 합산 tick. 실패하면 nil.
    public static func current() -> CPUTicks? {
        var info = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride
        )
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(hostPort, HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        let t = info.cpu_ticks // (USER, SYSTEM, IDLE, NICE)
        return CPUTicks(user: UInt64(t.0), system: UInt64(t.1), idle: UInt64(t.2), nice: UInt64(t.3))
    }
}
```

`Sources/DallyeoraCore/AnimationClock.swift`:
```swift
import Foundation

public enum AnimationClock {
    /// 프레임마다 더하는 phase(rad).
    public static let phaseStep = 0.6

    /// CPU 0% → 0.2초, 100% → 0.03초.
    public static func frameInterval(cpu: Double) -> TimeInterval {
        0.2 - CPUUsage.clamp(cpu) / 100 * 0.17
    }
}
```

- [ ] **Step 5: 통과 확인**

Run: `swift test`
Expected: 모든 테스트 PASS

- [ ] **Step 6: 커밋 지점** — `feat: add CPU usage sampling and animation clock`

---

### Task 2: 캐릭터 4종 (문구 단계 + 그리기)

**Files:**
- Create: `Sources/DallyeoraCore/Mascot.swift`, `Sources/DallyeoraCore/Drawing.swift`, `Sources/DallyeoraCore/Mascots/Sunfish.swift`, `Worker.swift`, `Pork.swift`, `Rider.swift`
- Test: `Tests/DallyeoraCoreTests/MascotTests.swift`, `Tests/DallyeoraCoreTests/RenderTests.swift`

**Interfaces:**
- Consumes: `CPUUsage.clamp(_:)`
- Produces:
  - `public enum Tone: String, CaseIterable, Sendable { case standard, gyeongsang; var label: String }`
  - `public struct Tier: Sendable { minCPU: Double; standard: String; gyeongsang: String; func text(_ tone: Tone) -> String }`
  - `public protocol Mascot: Sendable { var id: String; var name: String; var tiers: [Tier]; func draw(in: CGContext, phase: Double, cpu: Double) }`
  - `extension Mascot { func tierIndex(for cpu: Double) -> Int; func phrase(cpu: Double, tone: Tone) -> String }`
  - `public enum Mascots { static let all: [any Mascot]; static let defaultID: String; static var `default`: any Mascot; static func find(_ id: String) -> (any Mascot)? }`
  - `public enum MascotRenderer { static let size: CGSize; static func render(_: any Mascot, phase: Double, cpu: Double, scale: CGFloat = 2) -> CGImage? }`

- [ ] **Step 1: 실패하는 테스트 작성**

`Tests/DallyeoraCoreTests/MascotTests.swift`:
```swift
import Testing
@testable import DallyeoraCore

struct MascotTests {
    @Test func orderAndDefault() {
        #expect(Mascots.all.map(\.id) == ["sunfish", "worker", "pork", "rider"])
        #expect(Mascots.defaultID == "sunfish")
        #expect(Mascots.default.id == "sunfish")
        #expect(Mascots.find("pork")?.name == "삼겹살 불판")
        #expect(Mascots.find("cat") == nil)
    }

    @Test func everyMascotHasFourAscendingTiersFromZero() {
        for m in Mascots.all {
            #expect(m.tiers.count == 4)
            #expect(m.tiers.first?.minCPU == 0)
            #expect(zip(m.tiers, m.tiers.dropFirst()).allSatisfy { $0.minCPU < $1.minCPU })
        }
    }

    @Test(arguments: [(24.9, 0), (25.0, 1), (49.9, 1), (50.0, 2), (89.9, 2), (90.0, 3), (100.0, 3)])
    func sunfishTierBoundaries(cpu: Double, index: Int) {
        #expect(Mascots.find("sunfish")!.tierIndex(for: cpu) == index)
    }

    @Test(arguments: [(74.9, 2), (75.0, 3)])
    func workerTopTierStartsAt75(cpu: Double, index: Int) {
        #expect(Mascots.find("worker")!.tierIndex(for: cpu) == index)
    }

    @Test(arguments: [-5.0, Double.nan, Double.infinity])
    func invalidCPUUsesFirstTier(cpu: Double) {
        for m in Mascots.all {
            #expect(m.tierIndex(for: cpu) == 0)
        }
    }

    @Test func phraseFollowsTone() {
        let fish = Mascots.find("sunfish")!
        #expect(fish.phrase(cpu: 95, tone: .standard) == "충격으로 사망… 앱 좀 꺼 주세요")
        #expect(fish.phrase(cpu: 95, tone: .gyeongsang) == "마 죽었다… 앱 좀 꺼라")
        #expect(Mascots.find("rider")!.phrase(cpu: 60, tone: .gyeongsang) == "간다 안 카나")
        #expect(Tone.gyeongsang.label == "경상도")
    }
}
```

`Tests/DallyeoraCoreTests/RenderTests.swift`:
```swift
import CoreGraphics
import Testing
@testable import DallyeoraCore

struct RenderTests {
    @Test(arguments: [0.0, 30.0, 60.0, 95.0])
    func everyMascotDrawsVisiblePixels(cpu: Double) throws {
        for m in Mascots.all {
            let image = try #require(MascotRenderer.render(m, phase: 1.0, cpu: cpu))
            #expect(image.width == 56)
            #expect(image.height == 36)
            #expect(alphaBytes(image).filter { $0 > 0 }.count > 20, "\(m.id) at \(cpu)%")
        }
    }

    @Test func sunfishFlipsAtNinety() throws {
        let fish = try #require(Mascots.find("sunfish"))
        let alive = try #require(MascotRenderer.render(fish, phase: 0, cpu: 89))
        let dead = try #require(MascotRenderer.render(fish, phase: 0, cpu: 90))
        #expect(alphaBytes(alive) != alphaBytes(dead))
    }

    @Test(arguments: [Double.nan, -20.0, 400.0])
    func invalidCPUStillRenders(cpu: Double) {
        for m in Mascots.all {
            #expect(MascotRenderer.render(m, phase: 0, cpu: cpu) != nil)
        }
    }
}

/// 이미지를 RGBA 버퍼로 다시 그려 알파 채널만 꺼낸다.
func alphaBytes(_ image: CGImage) -> [UInt8] {
    let w = image.width, h = image.height
    var buffer = [UInt8](repeating: 0, count: w * h * 4)
    buffer.withUnsafeMutableBytes { raw in
        let ctx = CGContext(
            data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    }
    return stride(from: 3, to: buffer.count, by: 4).map { buffer[$0] }
}
```

- [ ] **Step 2: 실패 확인**

Run: `swift test`
Expected: 컴파일 실패 — `cannot find 'Mascots' in scope`

- [ ] **Step 3: 공통 타입 구현**

`Sources/DallyeoraCore/Mascot.swift`:
```swift
import CoreGraphics

public enum Tone: String, CaseIterable, Sendable {
    case standard
    case gyeongsang

    public var label: String {
        switch self {
        case .standard: "표준어"
        case .gyeongsang: "경상도"
        }
    }
}

public struct Tier: Sendable {
    public let minCPU: Double
    public let standard: String
    public let gyeongsang: String

    public init(_ minCPU: Double, _ standard: String, _ gyeongsang: String) {
        self.minCPU = minCPU
        self.standard = standard
        self.gyeongsang = gyeongsang
    }

    public func text(_ tone: Tone) -> String {
        tone == .standard ? standard : gyeongsang
    }
}

/// 메뉴 막대 캐릭터. 좌표계는 28×18, y축 아래 방향.
public protocol Mascot: Sendable {
    var id: String { get }
    var name: String { get }
    /// minCPU 오름차순, 첫 단계는 0.
    var tiers: [Tier] { get }
    func draw(in ctx: CGContext, phase: Double, cpu: Double)
}

extension Mascot {
    public func tierIndex(for cpu: Double) -> Int {
        let c = CPUUsage.clamp(cpu)
        return tiers.lastIndex { $0.minCPU <= c } ?? 0
    }

    public func phrase(cpu: Double, tone: Tone) -> String {
        tiers[tierIndex(for: cpu)].text(tone)
    }
}

public enum Mascots {
    public static let all: [any Mascot] = [Sunfish(), Worker(), Pork(), Rider()]
    public static let defaultID = "sunfish"
    public static var `default`: any Mascot { all[0] }

    public static func find(_ id: String) -> (any Mascot)? {
        all.first { $0.id == id }
    }
}
```

`Sources/DallyeoraCore/Drawing.swift`:
```swift
import CoreGraphics

public enum MascotRenderer {
    public static let size = CGSize(width: 28, height: 18)

    /// 검은 단색으로 그린 이미지. 앱에서 template 이미지로 쓴다.
    public static func render(_ mascot: any Mascot, phase: Double, cpu: Double, scale: CGFloat = 2) -> CGImage? {
        let w = Int(size.width * scale), h = Int(size.height * scale)
        guard let ctx = CGContext(
            data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.translateBy(x: 0, y: CGFloat(h))
        ctx.scaleBy(x: scale, y: -scale)
        let black = CGColor(gray: 0, alpha: 1)
        ctx.setStrokeColor(black)
        ctx.setFillColor(black)
        ctx.setLineWidth(1.3)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        mascot.draw(in: ctx, phase: phase, cpu: CPUUsage.clamp(cpu))
        return ctx.makeImage()
    }
}

extension CGContext {
    func line(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) {
        beginPath()
        move(to: CGPoint(x: x1, y: y1))
        addLine(to: CGPoint(x: x2, y: y2))
        strokePath()
    }

    func circle(_ x: Double, _ y: Double, _ r: Double, fill: Bool = false, alpha: Double = 1) {
        saveGState()
        setAlpha(alpha)
        let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
        if fill { fillEllipse(in: rect) } else { strokeEllipse(in: rect) }
        restoreGState()
    }

    func triangle(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double, _ x3: Double, _ y3: Double) {
        beginPath()
        move(to: CGPoint(x: x1, y: y1))
        addLine(to: CGPoint(x: x2, y: y2))
        addLine(to: CGPoint(x: x3, y: y3))
        closePath()
        fillPath()
    }

    func wheel(_ x: Double, _ y: Double, _ angle: Double) {
        circle(x, y, 2.5)
        line(x, y, x + cos(angle) * 2.5, y + sin(angle) * 2.5)
    }
}

/// 0..<1 로 접기 (음수 없음 가정).
func frac(_ x: Double) -> Double { x - x.rounded(.down) }
```

- [ ] **Step 4: 캐릭터 4종 구현 (시안 페이지의 그림을 그대로 옮김)**

`Sources/DallyeoraCore/Mascots/Sunfish.swift`:
```swift
import CoreGraphics
import Foundation

struct Sunfish: Mascot {
    let id = "sunfish"
    let name = "개복치"
    let tiers = [
        Tier(0, "평온하게 헤엄 중", "편하게 헤엄치는 중이다"),
        Tier(25, "햇빛에 깜짝 놀람", "깜짝 놀랐다 아이가"),
        Tier(50, "스트레스로 위독", "스트레스 받아 죽겠다"),
        Tier(90, "충격으로 사망… 앱 좀 꺼 주세요", "마 죽었다… 앱 좀 꺼라"),
    ]

    func draw(in ctx: CGContext, phase p: Double, cpu: Double) {
        let dead = cpu >= 90
        let jitter = (cpu >= 50 && !dead) ? (cpu - 40) / 60 * 1.1 : 0
        ctx.saveGState()
        ctx.translateBy(x: 14 + sin(p * 7.3) * jitter, y: 9 + sin(p * 0.6) * (dead ? 0.3 : 0.9))
        if dead { ctx.rotate(by: .pi) }
        ctx.strokeEllipse(in: CGRect(x: -6, y: -5.2, width: 12, height: 10.4))
        let fin = sin(p) * 1.4
        ctx.triangle(-1, -4.6, 2, -4.6, 0.4 + fin * 0.4, -8.6)   // 등지느러미
        ctx.triangle(-1, 4.6, 2, 4.6, 0.4 - fin * 0.4, 8.6)      // 배지느러미
        ctx.line(-6, -3.4, -7.6, 0)                              // 잘린 꼬리
        ctx.line(-7.6, 0, -6, 3.4)
        if dead {
            ctx.line(2.4, -2.4, 4, -0.8)
            ctx.line(4, -2.4, 2.4, -0.8)
        } else {
            ctx.circle(3.2, -1.4, 0.9, fill: true)
        }
        ctx.restoreGState()
        if cpu >= 50 && !dead {
            ctx.circle(22.6, 3 + frac(p * 0.5) * 3, 0.8, fill: true)   // 땀방울
        }
        if cpu < 25 {
            let t = frac(p * 0.12)
            ctx.circle(22, 12 - t * 10, 0.9, alpha: 1 - t)             // 물방울
        }
    }
}
```

`Sources/DallyeoraCore/Mascots/Worker.swift`:
```swift
import CoreGraphics
import Foundation

struct Worker: Mascot {
    let id = "worker"
    let name = "퇴근하는 김대리"
    let tiers = [
        Tier(0, "월급루팡 중", "월급 받고 노는 중이데이"),
        Tier(25, "일하는 척하는 중", "일하는 척 하고 있다 아이가"),
        Tier(50, "오늘 야근 각", "오늘 야근이다, 마"),
        Tier(75, "칼퇴 질주!", "퇴근한다, 비키라!"),
    ]

    func draw(in ctx: CGContext, phase p: Double, cpu: Double) {
        let lean = cpu / 100 * 2.6
        let amp = 0.35 + cpu / 100 * 0.85
        let hx = 13 + lean
        if cpu >= 75 {
            for i in 0..<3 {
                let fi = Double(i)
                let o = (p * 3 + fi * 2).truncatingRemainder(dividingBy: 3)
                ctx.line(1 + o, 7 + fi * 3, 5 + o, 7 + fi * 3)       // 속도선
            }
        }
        ctx.circle(hx + 1.4, 3.6, 2.4)                               // 머리
        ctx.line(hx + 0.8, 6.1, 13, 11.4)                            // 몸통
        ctx.line(hx + 0.9, 6.9, hx + 1.9, 8.5)                       // 넥타이
        let s = sin(p), c = sin(p + .pi)
        ctx.line(13, 11.4, 13 + s * 3.6 * amp, 16.6)                 // 다리
        ctx.line(13, 11.4, 13 + c * 3.6 * amp, 16.6)
        let ax = hx + 0.6 + c * 3.2 * amp, ay = 10.6
        ctx.line(hx + 0.6, 7.4, ax, ay)                              // 가방 든 팔
        ctx.line(hx + 0.6, 7.4, hx + 0.6 + s * 3 * amp, 10.2)
        ctx.fill(CGRect(x: ax - 1.8, y: ay, width: 3.6, height: 2.6)) // 서류가방
    }
}
```

`Sources/DallyeoraCore/Mascots/Pork.swift`:
```swift
import CoreGraphics
import Foundation

struct Pork: Mascot {
    let id = "pork"
    let name = "삼겹살 불판"
    let tiers = [
        Tier(0, "불판 달구는 중", "아직 불도 안 올랐다"),
        Tier(25, "지글지글", "지글지글하네"),
        Tier(50, "지금 뒤집어!", "퍼뜩 뒤집으라"),
        Tier(75, "탄다 탄다! 노트북 뜨거움", "다 탔다 아이가"),
    ]

    func draw(in ctx: CGContext, phase p: Double, cpu: Double) {
        ctx.line(3, 16, 25, 16)                                      // 불판
        for x in stride(from: 5.0, through: 23, by: 3) { ctx.line(x, 16, x, 17.4) }
        let flip = cpu >= 75 ? cos(p * 0.7) : 1
        let h = 3.2 * abs(flip), y0 = 14.6 - h
        ctx.fill(CGRect(x: 7, y: y0, width: 14, height: h))          // 고기
        if h > 1.4 {
            ctx.setBlendMode(.clear)                                 // 비계 줄
            ctx.fill(CGRect(x: 7, y: y0 + h * 0.42, width: 14, height: 0.7))
            ctx.setBlendMode(.normal)
        }
        let puffs = 1 + Int(cpu / 25)
        for i in 0..<puffs {
            let fi = Double(i)
            let t = frac(p * 0.18 + fi / Double(puffs))
            let x = 9 + fi * 3.4 + sin(t * 6 + fi) * 1.2
            ctx.circle(x, 10 - t * 9, 0.7 + t * 1.3, alpha: 1 - t)   // 연기
        }
    }
}
```

`Sources/DallyeoraCore/Mascots/Rider.swift`:
```swift
import CoreGraphics
import Foundation

struct Rider: Mascot {
    let id = "rider"
    let name = "배달 라이더"
    let tiers = [
        Tier(0, "조리 중…", "아직 음식 만드는 중이다"),
        Tier(25, "픽업 완료", "음식 받았다"),
        Tier(50, "배달 중", "간다 안 카나"),
        Tier(75, "곧 도착합니다!", "다 왔다, 문 열어라"),
    ]

    func draw(in ctx: CGContext, phase p: Double, cpu: Double) {
        let moving = cpu >= 25
        let bump = moving ? abs(sin(p * 1.3)) * (cpu / 100) * 1.1 : 0
        if cpu >= 75 {
            for i in 0..<3 {
                let fi = Double(i)
                ctx.line(0.5, 9 + fi * 2.6, 3 + (p + fi).truncatingRemainder(dividingBy: 2), 9 + fi * 2.6)
            }
        }
        ctx.saveGState()
        ctx.translateBy(x: 0, y: -bump)
        let spin = moving ? p : 0
        ctx.wheel(8, 14.6, spin)
        ctx.wheel(21.5, 14.6, spin)
        ctx.line(8, 14.6, 12, 11.6)                                  // 차체
        ctx.line(12, 11.6, 19, 11.6)
        ctx.line(19, 11.6, 21.5, 14.6)
        ctx.line(19.6, 11.6, 21.6, 5.8)                              // 핸들
        ctx.line(21.6, 5.8, 23.4, 5.8)
        ctx.stroke(CGRect(x: 4.2, y: 5.2, width: 6.4, height: 5.4))  // 배달통
        ctx.circle(15.6, 3.2, 2.1)                                   // 라이더
        ctx.line(15.2, 5.3, 14, 10.6)
        ctx.line(15.4, 6.6, 21, 6.4)
        if !moving {
            let t = frac(p * 0.15), t2 = frac(p * 0.15 + 0.5)        // 김
            ctx.line(6.4, 4 - t * 3.6, 7.4, 3 - t * 3.6)
            ctx.line(8.6, 4 - t2 * 3.6, 9.4, 3 - t2 * 3.6)
        }
        ctx.restoreGState()
    }
}
```

- [ ] **Step 5: 통과 확인**

Run: `swift test`
Expected: 모든 테스트 PASS

- [ ] **Step 6: 커밋 지점** — `feat: add four meme mascots with tiered phrases`

---

### Task 3: 설정 저장

**Files:**
- Create: `Sources/DallyeoraCore/Settings.swift`
- Test: `Tests/DallyeoraCoreTests/SettingsTests.swift`

**Interfaces:**
- Consumes: `Mascots.find(_:)`, `Mascots.defaultID`, `Tone`
- Produces: `@MainActor public final class Settings { init(defaults: UserDefaults = .standard); var mascotID: String; var tone: Tone; enum Key { static let mascot, tone } }`

- [ ] **Step 1: 실패하는 테스트 작성**

`Tests/DallyeoraCoreTests/SettingsTests.swift`:
```swift
import Foundation
import Testing
@testable import DallyeoraCore

@MainActor
@Suite(.serialized)
struct SettingsTests {
    static let suite = "com.cozynye.dallyeora.tests"
    let defaults: UserDefaults

    init() {
        defaults = UserDefaults(suiteName: Self.suite)!
        defaults.removePersistentDomain(forName: Self.suite)
    }

    @Test func defaultsToSunfishAndStandard() {
        let s = Settings(defaults: defaults)
        #expect(s.mascotID == "sunfish")
        #expect(s.tone == .standard)
    }

    @Test func persistsChoicesAcrossInstances() {
        let s = Settings(defaults: defaults)
        s.mascotID = "pork"
        s.tone = .gyeongsang
        let reloaded = Settings(defaults: defaults)
        #expect(reloaded.mascotID == "pork")
        #expect(reloaded.tone == .gyeongsang)
    }

    @Test func unknownStoredValuesFallBack() {
        defaults.set("cat", forKey: Settings.Key.mascot)
        defaults.set("jeolla", forKey: Settings.Key.tone)
        let s = Settings(defaults: defaults)
        #expect(s.mascotID == "sunfish")
        #expect(s.tone == .standard)
    }
}
```

- [ ] **Step 2: 실패 확인**

Run: `swift test --filter SettingsTests`
Expected: 컴파일 실패 — `cannot find 'Settings' in scope`

- [ ] **Step 3: 구현**

`Sources/DallyeoraCore/Settings.swift`:
```swift
import Foundation

/// 선택한 캐릭터와 말투. 알 수 없는 저장값은 기본값으로 돌아간다.
@MainActor
public final class Settings {
    public enum Key {
        public static let mascot = "mascotID"
        public static let tone = "tone"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var mascotID: String {
        get { defaults.string(forKey: Key.mascot).flatMap { Mascots.find($0)?.id } ?? Mascots.defaultID }
        set { defaults.set(newValue, forKey: Key.mascot) }
    }

    public var tone: Tone {
        get { defaults.string(forKey: Key.tone).flatMap(Tone.init(rawValue:)) ?? .standard }
        set { defaults.set(newValue.rawValue, forKey: Key.tone) }
    }
}
```

- [ ] **Step 4: 통과 확인 + 테스트용 설정 파일 정리**

Run: `swift test && defaults delete com.cozynye.dallyeora.tests 2>/dev/null; true`
Expected: 모든 테스트 PASS

- [ ] **Step 5: 커밋 지점** — `feat: persist mascot and tone choices`

---

### Task 4: 메뉴 막대 앱

**Files:**
- Modify: `Sources/Dallyeora/main.swift` (전체 교체)
- Create: `Sources/Dallyeora/AppDelegate.swift`, `Sources/Dallyeora/StatusItemController.swift`

**Interfaces:**
- Consumes: Task 1–3의 모든 public API

- [ ] **Step 1: 진입점**

`Sources/Dallyeora/main.swift`:
```swift
import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
```

`Sources/Dallyeora/AppDelegate.swift`:
```swift
import AppKit
import DallyeoraCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = StatusItemController(settings: Settings())
    }
}
```

- [ ] **Step 2: 상태 아이템 컨트롤러**

`Sources/Dallyeora/StatusItemController.swift`:
```swift
import AppKit
import DallyeoraCore

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let settings: Settings
    private let headerItem = NSMenuItem()
    private let phraseItem = NSMenuItem()
    private let mascotMenu = NSMenu()
    private let toneMenu = NSMenu()
    private var cpu: Double = 0
    private var phase: Double = 0
    private var lastTicks: CPUTicks?
    private var cpuTimer: Timer?
    private var frameTimer: Timer?

    private var mascot: any Mascot { Mascots.find(settings.mascotID) ?? Mascots.default }

    init(settings: Settings) {
        self.settings = settings
        super.init()
        buildMenu()
        sampleCPU()
        startCPUTimer()
        render()
        scheduleNextFrame()
    }

    // MARK: 타이머 — 메뉴가 열려 있어도 돌도록 .common 모드에 등록

    private func startCPUTimer() {
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sampleCPU() }
        }
        RunLoop.main.add(timer, forMode: .common)
        cpuTimer = timer
    }

    private func scheduleNextFrame() {
        let timer = Timer(timeInterval: AnimationClock.frameInterval(cpu: cpu), repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        frameTimer = timer
    }

    private func tick() {
        phase += AnimationClock.phaseStep
        render()
        scheduleNextFrame()
    }

    private func sampleCPU() {
        guard let now = CPUTicks.current() else { return }
        if let last = lastTicks {
            cpu = CPUUsage.percent(from: last, to: now)
        }
        lastTicks = now
    }

    // MARK: 그리기

    private func render() {
        guard let button = statusItem.button else { return }
        let m = mascot
        if let cg = MascotRenderer.render(m, phase: phase, cpu: cpu) {
            let image = NSImage(cgImage: cg, size: MascotRenderer.size)
            image.isTemplate = true
            button.image = image
        }
        button.imagePosition = .imageLeading
        let text = m.phrase(cpu: cpu, tone: settings.tone)
        let title = " " + text
        if button.title != title { button.title = title }
        headerItem.title = "\(m.name)    CPU \(Int(cpu.rounded()))%"
        phraseItem.title = text
    }

    // MARK: 메뉴

    private func buildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        headerItem.isEnabled = false
        phraseItem.isEnabled = false
        menu.addItem(headerItem)
        menu.addItem(phraseItem)
        menu.addItem(.separator())

        for m in Mascots.all {
            let item = NSMenuItem(title: m.name, action: #selector(selectMascot(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = m.id
            mascotMenu.addItem(item)
        }
        let mascotItem = NSMenuItem(title: "캐릭터", action: nil, keyEquivalent: "")
        mascotItem.submenu = mascotMenu
        menu.addItem(mascotItem)

        for tone in Tone.allCases {
            let item = NSMenuItem(title: tone.label, action: #selector(selectTone(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = tone.rawValue
            toneMenu.addItem(item)
        }
        let toneItem = NSMenuItem(title: "말투", action: nil, keyEquivalent: "")
        toneItem.submenu = toneMenu
        menu.addItem(toneItem)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)

        statusItem.menu = menu
        updateChecks()
    }

    func menuWillOpen(_ menu: NSMenu) {
        updateChecks()
        render()
    }

    private func updateChecks() {
        for item in mascotMenu.items {
            item.state = (item.representedObject as? String) == settings.mascotID ? .on : .off
        }
        for item in toneMenu.items {
            item.state = (item.representedObject as? String) == settings.tone.rawValue ? .on : .off
        }
    }

    @objc private func selectMascot(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        settings.mascotID = id
        updateChecks()
        render()
    }

    @objc private func selectTone(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let tone = Tone(rawValue: raw) else { return }
        settings.tone = tone
        updateChecks()
        render()
    }
}
```

- [ ] **Step 3: 빌드 + 기존 테스트 확인**

Run: `swift build 2>&1 | tail -5 && swift test 2>&1 | tail -3`
Expected: 경고/에러 없이 빌드, 테스트 PASS. Swift 6 동시성 에러가 나면 `swift-concurrency-pro` 스킬의 `references/diagnostics.md`를 참고해 고친다 (`@unchecked Sendable`로 덮지 않는다).

- [ ] **Step 4: 실행해서 눈으로 확인**

Run: `swift run Dallyeora` (백그라운드 실행)

확인 항목:
1. 메뉴 막대에 개복치 + "평온하게 헤엄 중" 류 문구가 보인다.
2. CPU를 올린다: `for i in $(seq $(sysctl -n hw.ncpu)); do yes > /dev/null & done` → 몇 초 뒤 개복치가 떨다가 뒤집히고 "충격으로 사망…" 문구가 나온다. 확인 후 `killall yes`.
3. 메뉴를 연 채로 CPU %와 아이콘이 계속 바뀐다 (Review Focus 4).
4. 캐릭터 4종, 말투 2종을 바꿔 본다. 앱을 종료했다가 다시 실행하면 선택이 유지된다.
5. 시스템 설정에서 다크/라이트 모드를 바꿔도 아이콘이 보인다 (Review Focus 5).

- [ ] **Step 5: 커밋 지점** — `feat: add menu bar app with animated mascots`

---

### Task 5: 패키징·문서

**Files:**
- Create: `scripts/make-app.sh`, `README.md`, `LICENSE`, `CLAUDE.md`

- [ ] **Step 1: 패키징 스크립트**

`scripts/make-app.sh`:
```bash
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
```

Run: `chmod +x scripts/make-app.sh && scripts/make-app.sh && lipo -archs dist/Dallyeora.app/Contents/MacOS/Dallyeora && open dist/Dallyeora.app`
Expected: `x86_64 arm64` 출력, 메뉴 막대에 개복치가 뜨고 Dock 아이콘은 없다. 유니버설 빌드가 실패하면 원인을 확인하고, 해결이 안 되면 arm64 전용으로 바꾸되 README에 그 사실을 적는다.

- [ ] **Step 2: README.md**

```markdown
# 달려라 메뉴바 (Dallyeora)

CPU를 많이 쓸수록 메뉴 막대의 캐릭터가 바빠지는 macOS 앱입니다. [RunCat](https://github.com/runcat-dev/RunCatNeo)에서 아이디어를 얻어 한국 밈 캐릭터로 만들었습니다.

| 캐릭터 | CPU 낮음 → 높음 |
|---|---|
| 개복치 (기본) | 평온하게 헤엄 중 → 햇빛에 깜짝 놀람 → 스트레스로 위독 → 충격으로 사망… 앱 좀 꺼 주세요 |
| 퇴근하는 김대리 | 월급루팡 중 → 일하는 척하는 중 → 오늘 야근 각 → 칼퇴 질주! |
| 삼겹살 불판 | 불판 달구는 중 → 지글지글 → 지금 뒤집어! → 탄다 탄다! 노트북 뜨거움 |
| 배달 라이더 | 조리 중… → 픽업 완료 → 배달 중 → 곧 도착합니다! |

메뉴에서 캐릭터와 말투(표준어 / 경상도)를 바꿀 수 있습니다.

## 설치

1. [Releases](../../releases)에서 `Dallyeora-x.y.z.zip`을 받아 압축을 풉니다.
2. `Dallyeora.app`을 `응용 프로그램` 폴더로 옮깁니다.
3. Apple 공증을 받지 않은 앱이라 처음 실행할 때는 **우클릭 → 열기**를 해야 합니다.
   macOS 15 이상에서 열리지 않으면 **시스템 설정 → 개인정보 보호 및 보안**에서 "그래도 열기"를 누르세요.

요구 사항: macOS 14 이상

## 직접 빌드

```bash
swift test            # 단위 테스트
swift run Dallyeora   # 바로 실행
scripts/make-app.sh   # dist/에 .app과 zip 생성
```

## 라이선스

MIT
```

- [ ] **Step 3: LICENSE (MIT, `Copyright (c) 2026 cozynye`), 프로젝트 CLAUDE.md**

`CLAUDE.md`:
```markdown
# 달려라 메뉴바

macOS 메뉴 막대 앱. Swift Package (Swift 6, macOS 14+), AppKit `NSStatusItem`.

- `Sources/DallyeoraCore`: AppKit 없는 로직과 그리기. 여기에 테스트를 붙인다.
- `Sources/Dallyeora`: 메뉴 막대 UI.
- 새 캐릭터: `Sources/DallyeoraCore/Mascots/`에 `Mascot` 구현 추가 → `Mascots.all`에 등록 → `MascotTests`의 순서 테스트 갱신.
- 그림 좌표는 28×18, y축 아래 방향, 단색.

명령: `swift test`, `swift run Dallyeora`, `scripts/make-app.sh [버전]`
설계: `docs/spec.md`
```

- [ ] **Step 4: 최종 확인**

Run: `swift test && git status --short`
Expected: 테스트 PASS, `.build/`·`dist/`는 목록에 없음.

- [ ] **Step 5: 커밋 지점** — `chore: add packaging script and docs`

GitHub repo 생성·push·Release 업로드·프로필 README 갱신은 외부 공개 작업이므로 사용자 확인 후 진행한다 (playground/CLAUDE.md의 계정 전환 절차를 따른다).
