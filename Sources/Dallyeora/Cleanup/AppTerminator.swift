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

    func isRunning(_ pid: pid_t) -> Bool {
        kill(pid, 0) == 0
    }

    func icon(forBundleAt path: String) -> NSImage {
        NSWorkspace.shared.icon(forFile: path)
    }
}
