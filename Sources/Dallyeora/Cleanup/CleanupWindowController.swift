import AppKit
import DallyeoraCore
import SwiftUI

/// 창은 하나만 만들고 재사용한다. 닫으면 타이머를 멈추고, 다시 열면 메뉴 막대 지표로 시작한다.
@MainActor
final class CleanupWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var model: CleanupModel?

    func show(metric: Metric) {
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }
        let model = self.model ?? CleanupModel(metric: metric)
        model.metric = metric
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 560, height: 440),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered, defer: false)
            window.title = "정리하기"
            window.minSize = NSSize(width: 480, height: 360)
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.contentView = NSHostingView(rootView: CleanupView(model: model) { [weak self] row in
                self?.confirmForceQuit(row, model: model)
            })
            window.center()
            self.window = window
        }
        self.model = model
        model.start()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func windowWillClose(_ notification: Notification) {
        model?.stop()
    }

    /// 강제 종료는 저장하지 않은 작업을 잃을 수 있어 한 번 묻는다.
    private func confirmForceQuit(_ row: CleanupModel.Row, model: CleanupModel) {
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
}
