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
