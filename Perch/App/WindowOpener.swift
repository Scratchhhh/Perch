import AppKit

/// Small bridge so non-view code (banner handlers) can open SwiftUI windows.
/// A view captures the environment `openWindow` action and stores it here.
@MainActor
final class WindowOpener {
    static let shared = WindowOpener()

    static let dashboardID = "dashboard"

    var open: ((String) -> Void)?

    private init() {}

    func focus(_ id: String = dashboardID) {
        NSApplication.shared.activate()
        open?(id)
    }
}
