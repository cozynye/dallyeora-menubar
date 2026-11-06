import Foundation
import Testing
@testable import DallyeoraCore

struct UsageRankerTests {
    func sample(_ pid: pid_t, cpu: UInt64, mem: UInt64 = 0) -> ProcessSample {
        ProcessSample(pid: pid, ppid: 1, uid: 501, name: "p\(pid)", path: "/p\(pid)", footprintBytes: mem, cpuTimeNanos: cpu)
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
        let cur = ProcessSnapshot(uptime: 2, samples: [sample(1, cpu: 4_800_000_000)]) // 4코어의 60%
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
        #expect(byCPU.map { $0.group.id } == ["/A.app", "/B.app"])
        #expect(byMemory.map { $0.group.id } == ["/B.app", "/A.app"])
    }

    @Test func tiesAreOrderedByID() {
        let cur = ProcessSnapshot(uptime: 1, samples: [])
        let groups = [bg("zeta", pids: [1], mem: 5), bg("alpha", pids: [2], mem: 5), bg("mid", pids: [3], mem: 5)]
        let rows = UsageRanker.rank(groups: groups, current: cur, previous: nil, cpuCount: 1,
                                    totals: .init(cpuPercent: nil, memoryBytes: 15), metric: .memory)
        #expect(rows.map { $0.group.id } == ["name:alpha", "name:mid", "name:zeta"])
    }

    /// 작은 앱도 끌 수 있어야 하므로 줄 수를 자르지 않는다(목록이 스크롤된다).
    @Test func keepsEveryRowBeyondFifteen() {
        let cur = ProcessSnapshot(uptime: 1, samples: [])
        let groups = (1...20).map { app("/\($0).app", pids: [pid_t($0)], mem: UInt64(100 * $0)) }
        let rows = UsageRanker.rank(groups: groups, current: cur, previous: nil, cpuCount: 1,
                                    totals: .init(cpuPercent: nil, memoryBytes: 30000), metric: .memory)
        #expect(rows.count == 20)
        #expect(rows.first?.group.id == "/20.app")
        #expect(rows.last?.group.id == "/1.app")
    }

    /// 줄을 펼치면 보이는 프로세스 목록. pid별 값이고 선택한 지표 순, 같으면 pid 순.
    @Test func membersCarryPerPIDValuesSortedByMetric() {
        let prev = ProcessSnapshot(uptime: 0, samples: [sample(1, cpu: 0), sample(2, cpu: 0), sample(3, cpu: 0)])
        let cur = ProcessSnapshot(uptime: 1, samples: [
            sample(1, cpu: 1_000_000_000, mem: 100), sample(2, cpu: 500_000_000, mem: 500), sample(3, cpu: 500_000_000, mem: 50),
        ])
        let groups = [app("/A.app", pids: [1, 2, 3], mem: 650), system]
        let byCPU = UsageRanker.rank(groups: groups, current: cur, previous: prev, cpuCount: 4,
                                     totals: .init(cpuPercent: 100, memoryBytes: 1000), metric: .cpu)
        let byMemory = UsageRanker.rank(groups: groups, current: cur, previous: prev, cpuCount: 4,
                                        totals: .init(cpuPercent: 100, memoryBytes: 1000), metric: .memory)
        let appByCPU = byCPU.first { $0.kind == .app }!
        #expect(appByCPU.members.map(\.pid) == [1, 2, 3])
        #expect(appByCPU.members.map(\.cpuPercent) == [25, 12.5, 12.5])
        #expect(appByCPU.members.map(\.name) == ["p1", "p2", "p3"])
        let appByMemory = byMemory.first { $0.kind == .app }!
        #expect(appByMemory.members.map(\.pid) == [2, 1, 3])
        #expect(appByMemory.members.map(\.memoryBytes) == [500, 100, 50])
        #expect(byCPU.first { $0.kind == .system }?.members.isEmpty == true)
    }

    @Test func membersHaveNoCPUWithoutPreviousSnapshot() {
        let cur = ProcessSnapshot(uptime: 1, samples: [sample(1, cpu: 5, mem: 10)])
        let rows = UsageRanker.rank(groups: [app("/A.app", pids: [1], mem: 10)], current: cur, previous: nil, cpuCount: 1,
                                    totals: .init(cpuPercent: nil, memoryBytes: 10), metric: .cpu)
        #expect(rows[0].members.map(\.cpuPercent) == [nil])
    }
}
