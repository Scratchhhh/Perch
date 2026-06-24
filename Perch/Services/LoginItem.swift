import Foundation
import ServiceManagement
import PerchCore

/// Thin wrapper over SMAppService for the "launch at login" toggle.
@MainActor
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
        PerchLog.app.info("login item enabled=\(enabled)")
    }
}
