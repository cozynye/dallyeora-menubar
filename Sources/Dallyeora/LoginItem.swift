import Foundation
import ServiceManagement

/// 로그인 항목 등록. 상태는 앱이 저장하지 않고 시스템에 묻는다.
@MainActor
struct LoginItem {
    /// `swift run`처럼 .app 번들 밖에서 뜨면 등록할 대상이 없다.
    var isAvailable: Bool { Bundle.main.bundleURL.pathExtension == "app" }
    var isEnabled: Bool { SMAppService.mainApp.status == .enabled }
    var needsApproval: Bool { SMAppService.mainApp.status == .requiresApproval }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
