import AppKit
import Carbon.HIToolbox

/// 어느 앱에서든 듣는 단축키 ⌃⌥⌘D. Carbon 단축키는 접근성 권한이 필요 없다.
@MainActor
final class GlobalHotKey {
    private let action: () -> Void
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?

    init(action: @escaping () -> Void) {
        self.action = action
    }

    /// 다른 앱이 이미 쓰고 있으면 false. 앱이 끝날 때까지 유지하므로 해제는 따로 하지 않는다.
    func register() -> Bool {
        guard hotKey == nil else { return true }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let installed = InstallEventHandler(
            GetApplicationEventTarget(), hotKeyPressed, 1, &spec,
            Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard installed == noErr else { return false }
        let id = EventHotKeyID(signature: OSType(0x444C_5952), id: 1) // 'DLYR'
        let registered = RegisterEventHotKey(
            UInt32(kVK_ANSI_D), UInt32(controlKey | optionKey | cmdKey), id,
            GetApplicationEventTarget(), 0, &hotKey)
        if registered != noErr, let handler {
            RemoveEventHandler(handler)
            self.handler = nil
        }
        return registered == noErr
    }

    fileprivate func fire() {
        action()
    }
}

/// Carbon은 C 함수 포인터만 받는다. 이벤트는 메인 런 루프에서 온다.
private func hotKeyPressed(_: EventHandlerCallRef?, _: EventRef?, _ userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let userData else { return noErr }
    let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
    MainActor.assumeIsolated { hotKey.fire() }
    return noErr
}
