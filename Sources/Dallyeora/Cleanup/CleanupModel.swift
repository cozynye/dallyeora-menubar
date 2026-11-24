import AppKit
import DallyeoraCore
import Observation

/// 스냅샷 → 묶기 → 순위 → 설명을 이어 화면용 행을 만든다. 창이 보이는 동안만 돈다.
@MainActor
@Observable
final class CleanupModel {
    struct Row: Identifiable {
        enum Badge { case quittable, background, system }
        typealias QuitState = QuitTracker.State

        /// 줄을 펼치면 보이는 프로세스 하나.
        struct Member: Identifiable {
            let pid: pid_t
            let name: String
            let usageText: String
            var id: pid_t { pid }
        }

        let id: String
        let title: String
        let summary: String
        let icon: NSImage?
        let usageText: String
        let badge: Badge
        /// 지금 데스크톱에 보이는 창 개수. 앱이 아니면 0.
        let windowCount: Int
        let mainPID: pid_t?
        let quitState: QuitState
        let members: [Member]
    }

    /// 종료를 요청한 뒤 이 시간이 지나도 살아 있으면 강제 종료 버튼으로 바꾼다. VS Code는 다 꺼지는 데 5초쯤 걸린다.
    static let forceQuitDelay: TimeInterval = 10

    /// 메뉴 막대와 같은 설정을 쓴다. 여기서 바꾸면 캐릭터가 반응하는 지표도 바뀐다.
    var metric: Metric {
        didSet {
            guard metric != oldValue else { return }
            settings.metric = metric
            if isHovering { freeze(rows: nil) } // 지표가 바뀌면 붙잡아 둔 순서는 의미가 없다
            rebuild()
        }
    }
    /// 검색어. 제목·설명·프로세스 이름에서 찾는다.
    var query = "" {
        didSet { if query != oldValue { rebuild() } }
    }
    /// 마우스가 목록 위에 있는 동안에는 줄 순서를 붙잡아 둔다.
    var isHovering = false {
        didSet {
            guard isHovering != oldValue else { return }
            freeze(rows: isHovering ? allRows : nil)
            if !isHovering { rebuild() }
        }
    }
    private(set) var rows: [Row] = []
    private(set) var totalText = ""
    private(set) var failed = false
    /// 아래 상태 줄에 잠깐 보이는 마지막 결과.
    private(set) var notice: String?
    /// 검색어에 맞는 줄이 없을 때 목록 자리에 보여 줄 글자.
    private(set) var emptyText: String?

    private let settings: Settings
    private let terminator = AppTerminator()
    private var settingsObserver: NSObjectProtocol?
    private var previous: ProcessSnapshot?
    private var current: ProcessSnapshot?
    private var lastTicks: CPUTicks?
    private var totalCPU: Double?
    private var memoryPercent: Double = 0
    private var memoryBytes: UInt64 = 0
    /// 줄마다의 종료 흐름(요청됨, 강제 종료 가능). 전이는 `QuitTracker`가 정한다.
    private var quits = QuitTracker()
    /// 검색으로 거르기 전의 전체 줄.
    private var allRows: [Row] = []
    private var frozenRowIDs: [String]?
    private var frozenMemberPIDs: [String: [pid_t]] = [:]
    private var timer: Timer?
    private var noticeTimer: Timer?

    init(settings: Settings) {
        self.settings = settings
        metric = settings.metric
        settingsObserver = NotificationCenter.default.addObserver(
            forName: Settings.didChange, object: settings, queue: nil
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.metric != settings.metric else { return }
                self.metric = settings.metric
            }
        }
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

    /// 창을 닫을 때 검색어와 붙잡아 둔 순서, 상태 줄, 기다리던 종료 요청을 비운다.
    func clearTransientState() {
        quits.reset()
        isHovering = false
        query = ""
        noticeTimer?.invalidate()
        notice = nil
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
        let windows = terminator.windowCounts()
        let built = ranked.map { makeRow($0, windows: windows) }
        let byID = Dictionary(built.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        // 종료를 요청해 둔 줄이 목록에서 사라졌으면 꺼진 것이다.
        for notice in quits.rowsDidChange(present: Set(byID.keys)) { post(notice) }

        allRows = StableOrder.arrange(built.map(\.id), keeping: frozenRowIDs).compactMap { byID[$0] }
        if isHovering { freeze(rows: allRows) } // 그사이 생긴 줄도 붙은 자리에 그대로 둔다
        rows = allRows.filter { row in
            RowFilter.matches(query: query, in: [row.title, row.summary] + row.members.map(\.name))
        }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        emptyText = rows.isEmpty && !trimmed.isEmpty ? "'\(trimmed)'에 맞는 항목이 없습니다" : nil
        let total = metric == .cpu ? (totalCPU.map(UsageFormat.percent) ?? "측정 중…") : UsageFormat.percent(memoryPercent)
        totalText = "지금 \(metric.label)를 많이 쓰는 것 · 전체 \(total)"
    }

    /// 지금 보이는 줄 순서와 줄 안의 프로세스 순서를 기억한다. nil이면 잊는다.
    private func freeze(rows: [Row]?) {
        frozenRowIDs = rows?.map(\.id)
        frozenMemberPIDs = Dictionary(
            (rows ?? []).map { ($0.id, $0.members.map(\.pid)) }, uniquingKeysWith: { first, _ in first })
    }

    private func usageText(cpuPercent: Double?, memoryBytes: UInt64) -> String {
        metric == .cpu ? (cpuPercent.map(UsageFormat.percent) ?? "측정 중…") : UsageFormat.bytes(memoryBytes)
    }

    private func makeRow(_ ranked: RankedRow, windows: [pid_t: Int]) -> Row {
        let group = ranked.group
        let usage = usageText(cpuPercent: ranked.cpuPercent, memoryBytes: ranked.memoryBytes)
        let byPID = Dictionary(ranked.members.map { ($0.pid, $0) }, uniquingKeysWith: { first, _ in first })
        let members = StableOrder.arrange(ranked.members.map(\.pid), keeping: frozenMemberPIDs[group.id])
            .compactMap { byPID[$0] }
            .map {
                Row.Member(pid: $0.pid, name: $0.name,
                           usageText: usageText(cpuPercent: $0.cpuPercent, memoryBytes: $0.memoryBytes))
            }

        if case .app(let bundle, _) = group.kind {
            let description = ProcessCatalog.describe(
                group, bundleID: AppBundleInfo.bundleID(at: bundle), localizedName: AppBundleInfo.displayName(at: bundle))
            let quitPID = group.quitTarget { terminator.canQuit($0) }
            let badge: Row.Badge = description.isProtected ? .system : (quitPID != nil ? .quittable : .background)
            let windowCount = group.pids.reduce(0) { $0 + (windows[$1] ?? 0) }
            return Row(id: group.id, title: description.title, summary: description.summary,
                       icon: terminator.icon(forBundleAt: bundle), usageText: usage, badge: badge,
                       windowCount: windowCount, mainPID: quitPID, quitState: quits.state(of: group.id),
                       members: members)
        }

        let description = ProcessCatalog.describe(group, bundleID: nil, localizedName: nil)
        let badge: Row.Badge = ranked.kind == .system ? .system : .background
        let title = ranked.kind == .background && ranked.count > 1 ? "\(description.title) ×\(ranked.count)" : description.title
        return Row(id: group.id, title: title, summary: description.summary, icon: nil, usageText: usage,
                   badge: badge, windowCount: 0, mainPID: nil, quitState: .idle, members: members)
    }

    // MARK: 상태 줄

    /// 결과를 `CleanupNotice.duration` 동안 보여 준다. 새 결과가 오면 바꿔 쓰고 시간을 다시 센다.
    private func post(_ result: CleanupNotice) {
        notice = result.text
        noticeTimer?.invalidate()
        let timer = Timer(timeInterval: CleanupNotice.duration, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.notice = nil }
        }
        RunLoop.main.add(timer, forMode: .common)
        noticeTimer = timer
    }

    // MARK: 종료

    func appName(of row: Row) -> String {
        row.title
    }

    /// 일반 종료. `forceQuitDelay` 뒤에도 살아 있으면 강제 종료 버튼으로 바뀐다.
    func quit(_ row: Row) {
        guard let pid = row.mainPID else { return }
        let (ticket, notice) = quits.request(id: row.id, name: row.title, sent: terminator.quit(pid))
        if let notice { post(notice) }
        rebuild()
        guard let ticket else { return }
        let check = Timer(timeInterval: Self.forceQuitDelay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                // 그사이 줄이 사라졌거나 새로 요청했으면 표가 맞지 않아 아무 일도 없다.
                guard let self,
                      let notice = self.quits.deadlinePassed(ticket, isRunning: self.terminator.isRunning(pid))
                else { return }
                self.post(notice)
                self.rebuild()
            }
        }
        RunLoop.main.add(check, forMode: .common)
    }

    func forceQuit(_ row: Row) {
        guard let pid = row.mainPID else { return }
        post(quits.forceQuit(id: row.id, name: row.title, done: terminator.forceQuit(pid)))
        rebuild()
    }

    /// 펼친 줄의 프로세스 하나만 끝낸다. 신호를 보냈으면 0.5초 뒤 다시 읽어 정말 끝났는지 본다.
    func quit(member: Row.Member) {
        let (pid, name) = (member.pid, member.name)
        switch terminator.terminateProcess(pid) {
        case .notPermitted:
            post(.processNotPermitted(name: name, pid: pid))
        case .noSuchProcess:
            post(.processAlreadyGone(name: name, pid: pid))
            refresh()
        case .failed:
            post(.processFailed(name: name, pid: pid))
        case .sent:
            let check = Timer(timeInterval: 0.5, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.refresh()
                    self.post(self.terminator.isRunning(pid)
                        ? .processStillRunning(name: name, pid: pid) : .processEnded(name: name, pid: pid))
                }
            }
            RunLoop.main.add(check, forMode: .common)
        }
    }
}
