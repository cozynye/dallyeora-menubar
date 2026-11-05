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
