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

        if case .app(let bundle, _) = group.kind {
            let description = ProcessCatalog.describe(
                group, bundleID: AppBundleInfo.bundleID(at: bundle), localizedName: AppBundleInfo.displayName(at: bundle))
            let quitPID = group.quitTarget { terminator.canQuit($0) }
            let badge: Row.Badge = description.isProtected ? .system : (quitPID != nil ? .quittable : .background)
            return Row(id: group.id, title: description.title, summary: description.summary,
                       icon: terminator.icon(forBundleAt: bundle), usageText: usage, badge: badge,
                       mainPID: quitPID, quitState: quitStates[group.id] ?? .idle)
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
