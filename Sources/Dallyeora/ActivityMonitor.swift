import AppKit
import DallyeoraCore

/// 화면이 잠들거나 다른 사용자로 전환되는 것을 듣고, 돌아야 하는지가 바뀔 때만 알린다.
@MainActor
final class ActivityMonitor {
    private var state = ActivityState()
    private var tokens: [NSObjectProtocol] = []
    private let onChange: (Bool) -> Void

    init(onChange: @escaping (Bool) -> Void) {
        self.onChange = onChange
        let events: [(Notification.Name, ActivityState.Event)] = [
            (NSWorkspace.screensDidSleepNotification, .screensDidSleep),
            (NSWorkspace.screensDidWakeNotification, .screensDidWake),
            (NSWorkspace.sessionDidResignActiveNotification, .sessionDidResignActive),
            (NSWorkspace.sessionDidBecomeActiveNotification, .sessionDidBecomeActive),
        ]
        let center = NSWorkspace.shared.notificationCenter
        for (name, event) in events {
            tokens.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.handle(event) }
            })
        }
    }

    private func handle(_ event: ActivityState.Event) {
        if state.handle(event) { onChange(state.isActive) }
    }
}
