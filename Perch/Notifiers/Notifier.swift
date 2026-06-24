import Foundation
import PerchCore

/// Anything that can surface a Perch signal to the user. v1 ships `LocalNotifier`
/// and `MascotNotifier`; the same shape leaves room for Telegram/ntfy later.
@MainActor
protocol Notifier: AnyObject {
    var id: String { get }
    func deliver(_ content: NotificationContent)
}

struct NotificationContent: Sendable {
    enum Category: String, Sendable {
        case done
        case attention
        case info
    }

    let title: String
    let body: String
    let category: Category
    let sessionId: String
    let projectPath: String?
    let source: AgentSource

    init(from message: RelayMessage) {
        sessionId = message.sessionId
        projectPath = message.project
        source = message.source

        let projectName: String
        if let project = message.project, !project.isEmpty {
            let last = URL(fileURLWithPath: project).lastPathComponent
            projectName = last.isEmpty ? project : last
        } else {
            projectName = message.source.displayName
        }

        let trimmed = message.message.trimmingCharacters(in: .whitespacesAndNewlines)

        switch message.kind {
        case .finished:
            title = "\(projectName) — done"
            body = trimmed.isEmpty ? "The agent finished its task." : trimmed
            category = .done
        case .needsInput, .permission, .blocked:
            title = "\(projectName) — needs you"
            body = trimmed.isEmpty ? "The agent is waiting for your input." : trimmed
            category = .attention
        case .started, .subagentDone:
            title = projectName
            body = trimmed
            category = .info
        }
    }
}
