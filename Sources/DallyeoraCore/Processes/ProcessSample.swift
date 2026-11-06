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
