import Foundation

/// 화면 한 줄이 되는 프로세스 묶음.
public struct ProcessGroup: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        /// 앱 번들로 묶임. `mainPID`는 종료 명령을 보낼 대표 프로세스.
        case app(bundlePath: String, mainPID: pid_t)
        /// 앱 번들이 없어 이름으로 묶임.
        case background(name: String)
        /// 다른 사용자 소유 전체. 수치는 없고 개수만.
        case system(count: Int)
    }

    public var id: String
    public var kind: Kind
    public var pids: [pid_t]
    public var footprintBytes: UInt64
    public var cpuTimeNanos: UInt64

    public init(id: String, kind: Kind, pids: [pid_t], footprintBytes: UInt64, cpuTimeNanos: UInt64) {
        self.id = id
        self.kind = kind
        self.pids = pids
        self.footprintBytes = footprintBytes
        self.cpuTimeNanos = cpuTimeNanos
    }
}
