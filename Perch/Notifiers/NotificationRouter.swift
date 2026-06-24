import AppKit
import PerchCore

/// Bridges banner interactions (clicks, action buttons) back into app navigation.
/// The closures are wired up by a view that owns the SwiftUI `openWindow` action.
@MainActor
final class NotificationRouter {
    static let shared = NotificationRouter()

    static let openProjectAction = "perch.open_project"
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
}
