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
    /// 두 측정 사이의 사용률(0–100). 변화가 없으면 0.
    /// 커널 카운터는 32비트라 한 번 0으로 돌아가도 차이가 맞도록 32비트로 감아서 뺀다.
    public static func percent(from old: CPUTicks, to new: CPUTicks) -> Double {
        func delta(_ a: UInt64, _ b: UInt64) -> UInt64 {
            UInt64(UInt32(truncatingIfNeeded: b) &- UInt32(truncatingIfNeeded: a))
        }
        let busy = delta(old.user, new.user) + delta(old.system, new.system) + delta(old.nice, new.nice)
        let total = busy + delta(old.idle, new.idle)
        guard total > 0 else { return 0 }
        return Usage.clamp(Double(busy) / Double(total) * 100)
    }
}

/// host_statistics 호출에 쓰는 포트. 한 번만 받아 CPU·메모리 측정이 함께 쓴다.
let hostPort = mach_host_self()

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
