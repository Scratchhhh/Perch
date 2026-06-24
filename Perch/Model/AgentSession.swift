import Foundation
import SwiftData
import PerchCore

@Model
final class AgentSession {
    @Attribute(.unique) var id: String
    var sourceRaw: String
    var projectPath: String?
    var label: String
    var startedAt: Date
    var lastActivityAt: Date
    var stateRaw: String

    @Relationship(deleteRule: .cascade, inverse: \AgentEvent.session)
    var events: [AgentEvent]

    init(
        id: String,
        source: AgentSource,
        projectPath: String?,
        label: String,
        startedAt: Date = .now,
        state: SessionState = .working
    ) {
        self.id = id
        self.sourceRaw = source.rawValue
        self.projectPath = projectPath
        self.label = label
        self.startedAt = startedAt
        self.lastActivityAt = startedAt
        self.stateRaw = state.rawValue
        self.events = []
    }

    var source: AgentSource {
        AgentSource(rawValue: sourceRaw) ?? .unknown
    }

    var state: SessionState {
        get { SessionState(rawValue: stateRaw) ?? .idle }
        set { stateRaw = newValue.rawValue }
    }

    static func deriveLabel(from message: RelayMessage) -> String {
        if let project = message.project, !project.isEmpty {
            let name = URL(fileURLWithPath: project).lastPathComponent
            return name.isEmpty ? project : name
        }
        return message.source.displayName
    }
}
