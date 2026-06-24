import Foundation
import SwiftData
import Observation
import PerchCore

/// The single point every channel feeds into. Incoming `RelayMessage`s are deduplicated,
/// persisted as `AgentEvent`/`AgentSession` rows, and forwarded to the registered notifiers.
@MainActor
@Observable
final class EventBus {
    private let modelContext: ModelContext
    private let dedup: Deduplicator
    private var notifiers: [Notifier]

    var doNotDisturb = false

    private(set) var workingCount = 0
    private(set) var waitingCount = 0
    private(set) var lastEventAt: Date?

    init(modelContext: ModelContext, notifiers: [Notifier], dedupWindow: TimeInterval = 5) {
        self.modelContext = modelContext
        self.dedup = Deduplicator(window: dedupWindow)
        self.notifiers = notifiers
        recomputeSummary()
    }

    var menuBarState: MenuBarState {
        if waitingCount > 0 { return .attention }
        if workingCount > 0 { return .thinking }
        return .calm
    }

    func register(_ notifier: Notifier) {
        notifiers.append(notifier)
    }

    func ingest(_ message: RelayMessage) {
        guard dedup.shouldProcess(sessionId: message.sessionId, kind: message.kind, at: message.timestamp) else {
            PerchLog.bus.debug("dropped duplicate \(message.kind.rawValue, privacy: .public) for session")
            return
        }

        persist(message)
        lastEventAt = message.timestamp
        recomputeSummary()

        guard !doNotDisturb else {
            PerchLog.bus.info("dnd active, suppressing banner for \(message.kind.rawValue, privacy: .public)")
            return
        }

        let content = NotificationContent(from: message)
        for notifier in notifiers {
            notifier.deliver(content)
        }
    }

    private func persist(_ message: RelayMessage) {
        let session = upsertSession(for: message)
        session.lastActivityAt = message.timestamp
        session.state = message.kind.resultingState

        let event = AgentEvent(
            ts: message.timestamp,
            source: message.source,
            channel: message.channel,
            kind: message.kind,
            message: message.message,
            transcriptPath: message.transcriptPath
        )
        event.session = session
        modelContext.insert(event)
        save()
    }

    private func upsertSession(for message: RelayMessage) -> AgentSession {
        let sessionId = message.sessionId
        var descriptor = FetchDescriptor<AgentSession>(predicate: #Predicate { $0.id == sessionId })
        descriptor.fetchLimit = 1

        if let existing = try? modelContext.fetch(descriptor).first {
            if let project = message.project, !project.isEmpty {
                existing.projectPath = project
                existing.label = AgentSession.deriveLabel(from: message)
            }
            return existing
        }

        let session = AgentSession(
            id: sessionId,
            source: message.source,
            projectPath: message.project,
            label: AgentSession.deriveLabel(from: message),
            startedAt: message.timestamp,
            state: message.kind.resultingState
        )
        modelContext.insert(session)
        return session
    }

    private func recomputeSummary() {
        workingCount = count(of: .working)
        waitingCount = count(of: .waiting)
    }

    private func count(of state: SessionState) -> Int {
        let raw = state.rawValue
        let descriptor = FetchDescriptor<AgentSession>(predicate: #Predicate { $0.stateRaw == raw })
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            PerchLog.bus.error("save failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
