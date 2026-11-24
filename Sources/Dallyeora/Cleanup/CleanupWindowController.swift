import AppKit
import DallyeoraCore
import SwiftUI

/// 창은 하나만 만들고 재사용한다. 닫으면 타이머를 멈추고 검색어를 비운다.
/// 프로세스를 읽을지는 `CleanupRunState`가 정하고, 여기서는 창과 화면의 변화를 넘겨주기만 한다.
@MainActor
final class CleanupWindowController: NSObject, NSWindowDelegate {
    private let model: CleanupModel
    private var window: NSWindow?
    private var runState = CleanupRunState()

    init(settings: DallyeoraCore.Settings) {
        model = CleanupModel(settings: settings)
    }

    func show() {
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 560, height: 440),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered, defer: false)
            window.title = "정리하기"
            window.minSize = NSSize(width: 480, height: 360)
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.contentView = NSHostingView(rootView: CleanupView(
                model: model,
                confirmForceQuit: { [weak self] in self?.confirmForceQuit($0) },
                confirmQuitMember: { [weak self] in self?.confirmQuit(member: $0) }))
            window.center()
            self.window = window
        }
        if window?.isMiniaturized == true { window?.deminiaturize(nil) }
        handle(.windowOpened)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    /// 화면이 꺼져 있는 동안에는 창이 열려 있어도 프로세스를 읽지 않는다.
    func setActive(_ active: Bool) {
        handle(active ? .screenBecameActive : .screenBecameInactive)
    }

    func windowWillClose(_ notification: Notification) {
        handle(.windowClosed)
        model.clearTransientState()
    }

    func windowDidMiniaturize(_ notification: Notification) {
        handle(.windowMiniaturized)
    }

    func windowDidDeminiaturize(_ notification: Notification) {
        handle(.windowDeminiaturized)
    }

    private func handle(_ event: CleanupRunState.Event) {
        guard runState.handle(event) else { return }
        if runState.shouldRun {
            model.start()
        } else {
            model.stop()
        }
    }

    /// 강제 종료는 저장하지 않은 작업을 잃을 수 있어 한 번 묻는다.
    private func confirmForceQuit(_ row: CleanupModel.Row) {
        let alert = NSAlert()
        alert.messageText = "\"\(model.appName(of: row))\"을(를) 강제 종료할까요?"
        alert.informativeText = "저장하지 않은 작업은 사라집니다."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "강제 종료")
        alert.addButton(withTitle: "취소")
        if alert.runModal() == .alertFirstButtonReturn {
            model.forceQuit(row)
        }
    }

    /// 프로세스 하나만 끄면 그 앱의 일부가 깨질 수 있어 한 번 묻는다.
    private func confirmQuit(member: CleanupModel.Row.Member) {
        let alert = NSAlert()
        alert.messageText = "\"\(member.name)\"(pid \(member.pid))을(를) 끌까요?"
        alert.informativeText = "이 앱의 탭이나 창, 확장 같은 일부가 깨질 수 있습니다."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "종료")
        alert.addButton(withTitle: "취소")
        if alert.runModal() == .alertFirstButtonReturn {
            model.quit(member: member)
        }
    }
}
