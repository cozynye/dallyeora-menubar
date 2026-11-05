import Darwin
import Foundation

/// 페이지 단위 메모리 통계. 활성 상태 보기의 "사용된 메모리"와 같은 기준으로 센다.
public struct MemoryPages: Equatable, Sendable {
    public var total: UInt64
    public var `internal`: UInt64
    public var purgeable: UInt64
    public var wired: UInt64
    public var compressed: UInt64

    public init(total: UInt64, internal: UInt64, purgeable: UInt64, wired: UInt64, compressed: UInt64) {
        self.total = total
        self.internal = `internal`
        self.purgeable = purgeable
        self.wired = wired
        self.compressed = compressed
    }

    /// 앱 메모리(internal - purgeable) + wired + 압축.
    public var used: UInt64 {
        (`internal` > purgeable ? `internal` - purgeable : 0) + wired + compressed
    }
}

public enum MemoryUsage {
    /// 전체 대비 사용 비율(0–100). 전체가 0이면 0.
    public static func percent(_ pages: MemoryPages) -> Double {
        guard pages.total > 0 else { return 0 }
        return CPUUsage.clamp(Double(pages.used) / Double(pages.total) * 100)
    }
}

private let memoryHostPort = mach_host_self()

extension MemoryPages {
    /// 현재 메모리 상태. 실패하면 nil.
    public static func current() -> MemoryPages? {
        var info = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride
        )
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(memoryHostPort, HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        let pageSize = UInt64(getpagesize())
        return MemoryPages(
            total: ProcessInfo.processInfo.physicalMemory / pageSize,
            internal: UInt64(info.internal_page_count),
            purgeable: UInt64(info.purgeable_count),
            wired: UInt64(info.wire_count),
            compressed: UInt64(info.compressor_page_count)
        )
    }
}
