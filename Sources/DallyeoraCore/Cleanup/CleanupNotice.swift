import Foundation

/// 정리하기 창 아래 상태 줄에 잠깐 보여 주는 결과.
public enum CleanupNotice: Equatable, Sendable {
    case quit(app: String)
    case quitNotSent(app: String)
    case unresponsive(app: String)
    case forceQuit(app: String)
    case forceQuitFailed(app: String)
    case processEnded(name: String, pid: Int32)
    case processStillRunning(name: String, pid: Int32)
    case processNotPermitted(name: String, pid: Int32)
    case processAlreadyGone(name: String, pid: Int32)
    case processFailed(name: String, pid: Int32)

    /// 상태 줄에 머무는 시간(초).
    public static let duration: TimeInterval = 5

    public var text: String {
        switch self {
        case .quit(let app): "종료했습니다: \(app)"
        case .quitNotSent(let app): "종료 요청을 보내지 못했습니다: \(app)"
        case .unresponsive(let app): "응답이 없어 강제 종료 버튼으로 바꿨습니다: \(app)"
        case .forceQuit(let app): "강제 종료했습니다: \(app)"
        case .forceQuitFailed(let app): "강제 종료하지 못했습니다: \(app)"
        case .processEnded(let name, let pid): "종료했습니다: \(name) (pid \(pid))"
        case .processStillRunning(let name, let pid): "종료를 요청했지만 아직 실행 중입니다: \(name) (pid \(pid))"
        case .processNotPermitted(let name, let pid): "권한이 없어 끌 수 없습니다: \(name) (pid \(pid))"
        case .processAlreadyGone(let name, let pid): "이미 끝난 프로세스입니다: \(name) (pid \(pid))"
        case .processFailed(let name, let pid): "끌 수 없습니다: \(name) (pid \(pid))"
        }
    }
}
