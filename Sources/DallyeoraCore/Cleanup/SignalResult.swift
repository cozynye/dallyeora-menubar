import Darwin

/// `kill`의 결과. 실패 이유에 따라 상태 줄 문구가 달라진다.
public enum SignalResult: Equatable, Sendable {
    case sent, notPermitted, noSuchProcess, failed

    public init(killResult: Int32, errno code: Int32) {
        if killResult == 0 {
            self = .sent
        } else {
            switch code {
            case EPERM: self = .notPermitted
            case ESRCH: self = .noSuchProcess
            default: self = .failed
            }
        }
    }
}
