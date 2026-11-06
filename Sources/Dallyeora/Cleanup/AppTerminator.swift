import AppKit

/// NSRunningApplication 감싸기. 스펙 3.7의 종료 가능 판정과 종료 명령.
@MainActor
struct AppTerminator {
    func application(_ pid: pid_t) -> NSRunningApplication? {
        NSRunningApplication(processIdentifier: pid)
    }

    /// Dock이나 메뉴 막대에 보이는 앱만.
    func canQuit(_ pid: pid_t) -> Bool {
        guard let app = application(pid) else { return false }
        return app.activationPolicy != .prohibited
    }

    /// ⌘Q와 같다. 저장하지 않은 문서가 있으면 그 앱이 묻는다. 요청을 보냈으면 true.
    func quit(_ pid: pid_t) -> Bool {
        application(pid)?.terminate() ?? false
    }

    func forceQuit(_ pid: pid_t) -> Bool {
        application(pid)?.forceTerminate() ?? false
    }

    /// 보조 프로세스 하나를 SIGTERM으로 끝낸다. 내 계정 프로세스만 권한이 있다.
    func terminateProcess(_ pid: pid_t) -> Bool {
        kill(pid, SIGTERM) == 0
    }

    func isRunning(_ pid: pid_t) -> Bool {
        kill(pid, 0) == 0
    }

    func icon(forBundleAt path: String) -> NSImage {
        NSWorkspace.shared.icon(forFile: path)
    }

    /// 지금 데스크톱에 보이는 일반 창 개수(pid별). 창 제목은 화면 녹화 권한이 필요해 읽지 않는다.
    func windowCounts() -> [pid_t: Int] {
        // kCGWindowOwnerPID, kCGWindowLayer 상수의 값은 이름과 같은 문자열이다.
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] ?? []
        var counts: [pid_t: Int] = [:]
        for window in list where (window["kCGWindowLayer"] as? Int) == 0 {
            if let pid = window["kCGWindowOwnerPID"] as? pid_t {
                counts[pid, default: 0] += 1
            }
        }
        return counts
    }
}
