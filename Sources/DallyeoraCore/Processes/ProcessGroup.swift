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

    /// 종료 명령을 보낼 pid. `mainPID`는 경로만 보고 고르기 때문에 Docker.app처럼
    /// Contents/MacOS 바로 아래에 백엔드를 두고 GUI를 안쪽 .app에 넣은 앱에서는 GUI가 아닐 수 있다.
    /// 그래서 끌 수 있는지(`canQuit`)를 pid 순으로 물어 첫 번째를 쓴다. 없으면 nil.
    public func quitTarget(where canQuit: (pid_t) -> Bool) -> pid_t? {
        pids.sorted().first(where: canQuit)
    }
}
