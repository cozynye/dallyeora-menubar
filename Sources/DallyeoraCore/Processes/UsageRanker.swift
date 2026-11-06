import Foundation

/// 줄을 펼치면 보이는 프로세스 하나.
public struct RankedMember: Equatable, Sendable {
    public var pid: pid_t
    public var name: String
    public var memoryBytes: UInt64
    /// 직전 스냅샷이 없으면 nil.
    public var cpuPercent: Double?

    public init(pid: pid_t, name: String, memoryBytes: UInt64, cpuPercent: Double?) {
        self.pid = pid
        self.name = name
        self.memoryBytes = memoryBytes
        self.cpuPercent = cpuPercent
    }
}

/// 정리하기 창의 한 줄.
public struct RankedRow: Equatable, Sendable {
    public enum Kind: Equatable, Sendable { case app, background, system }

    public var kind: Kind
    public var group: ProcessGroup
    /// 앱·백그라운드는 pid 수, 시스템은 프로세스 수.
    public var count: Int
    public var memoryBytes: UInt64
    /// 직전 스냅샷이 없으면 nil("측정 중…").
    public var cpuPercent: Double?
    /// 묶인 프로세스. 선택한 지표 순, 같으면 pid 순. 시스템 줄은 비어 있다.
    public var members: [RankedMember]

    public init(kind: Kind, group: ProcessGroup, count: Int, memoryBytes: UInt64, cpuPercent: Double?,
                members: [RankedMember] = []) {
        self.kind = kind
        self.group = group
        self.count = count
        self.memoryBytes = memoryBytes
        self.cpuPercent = cpuPercent
        self.members = members
    }
}

/// 스펙 3.5의 계산. 줄 수는 자르지 않는다(작은 앱도 끌 수 있어야 하고 목록은 스크롤된다).
public enum UsageRanker {
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
        cpuCount: Int, totals: Totals, metric: Metric
    ) -> [RankedRow] {
        let elapsed = previous.map { current.uptime - $0.uptime } ?? 0
        let canMeasureCPU = elapsed > 0 && cpuCount > 0
        let prevCPU = previous?.cpuTimeByPID ?? [:]
        let curCPU = current.cpuTimeByPID
        let samples = Dictionary(current.samples.map { ($0.pid, $0) }, uniquingKeysWith: { a, _ in a })

        // pid별 CPU 시간 차이. 새 pid나 줄어든 pid(번호 재사용)는 0.
        func delta(_ pid: pid_t) -> UInt64 {
            guard let p = prevCPU[pid], let c = curCPU[pid], c >= p else { return 0 }
            return c - p
        }
        func percent(_ nanos: UInt64) -> Double {
            Usage.clamp(Double(nanos) / (elapsed * 1e9) / Double(cpuCount) * 100)
        }

        var own: [RankedRow] = []
        var system: ProcessGroup?
        for g in groups {
            if case .system = g.kind {
                system = g
                continue
            }
            let cpu: Double? = canMeasureCPU ? percent(g.pids.reduce(UInt64(0)) { $0 + delta($1) }) : nil
            var members = g.pids.map { pid in
                RankedMember(pid: pid, name: samples[pid]?.name ?? "pid \(pid)",
                             memoryBytes: samples[pid]?.footprintBytes ?? 0,
                             cpuPercent: canMeasureCPU ? percent(delta(pid)) : nil)
            }
            members.sort { a, b in
                let (va, vb) = (value(of: a, metric), value(of: b, metric))
                return va != vb ? va > vb : a.pid < b.pid
            }
            let kind: RankedRow.Kind = if case .app = g.kind { .app } else { .background }
            own.append(RankedRow(kind: kind, group: g, count: g.pids.count, memoryBytes: g.footprintBytes,
                                 cpuPercent: cpu, members: members))
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
            return va != vb ? va > vb : a.group.id < b.group.id
        }
        return rows
    }

    static func value(of row: RankedRow, _ metric: Metric) -> Double {
        metric == .cpu ? (row.cpuPercent ?? 0) : Double(row.memoryBytes)
    }

    static func value(of member: RankedMember, _ metric: Metric) -> Double {
        metric == .cpu ? (member.cpuPercent ?? 0) : Double(member.memoryBytes)
    }
}
