import AppKit
import PerchCore

/// Bridges banner interactions (clicks, action buttons) back into app navigation.
/// The closures are wired up by a view that owns the SwiftUI `openWindow` action.
@MainActor
final class NotificationRouter {
    static let shared = NotificationRouter()

    static let openProjectAction = "perch.open_project"
    static let openTerminalAction = "perch.open_terminal"
    static let markDoneAction = "perch.mark_done"

    var onOpenDashboard: () -> Void = {}
    var onOpenProject: (String) -> Void = { _ in }

    private init() {}

    func handle(actionIdentifier: String, projectPath: String?) {
        switch actionIdentifier {
        case Self.openProjectAction:
            if let path = projectPath, !path.isEmpty {
                onOpenProject(path)
            } else {
                onOpenDashboard()
            }
        case Self.openTerminalAction:
            if let path = projectPath, !path.isEmpty {
                focusProject(path)
            } else {
                onOpenDashboard()
            }
        case Self.markDoneAction:
            break
        default:
            onOpenDashboard()
        }
    }

    func revealProject(_ path: String) {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// Closes the loop without injecting anything into the agent: opens the project directory in
    /// Terminal (frontmost) so the user can answer the prompt themselves. Falls back to revealing
    /// the folder in Finder if Terminal can't be located.
    func focusProject(_ path: String) {
        guard !path.isEmpty else { onOpenDashboard(); return }
        let url = URL(fileURLWithPath: path)
        guard let terminal = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") else {
            PerchLog.app.notice("Terminal not found; revealing project in Finder instead")
            revealProject(path)
            return
        }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.open([url], withApplicationAt: terminal, configuration: config) { _, error in
            if let error {
                PerchLog.app.error("open in terminal failed: \(error.localizedDescription, privacy: .public)")
                Task { @MainActor in self.revealProject(path) }
            }
        }
    }
}
