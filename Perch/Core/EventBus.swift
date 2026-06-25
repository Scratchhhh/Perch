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
    private let preferences: PreferencesStore
    private var notifiers: [Notifier]

    var doNotDisturb = false

    private(set) var workingCount = 0
    private(set) var waitingCount = 0
    private(set) var lastEventAt: Date?
    private(set) var lastKind: EventKind?

    /// Whether the "needs you" alert is currently active (drives the menu-bar icon and mascot).
    /// Clears when acknowledged and settles by itself after the TTL.
    private(set) var hasActiveAttention = false
    private var lastAttentionAt: Date?
    private let attentionTTL = AttentionPolicy.defaultTTL
    @ObservationIgnored private var attentionExpiry: Task<Void, Never>?

    init(modelContext: ModelContext, preferences: PreferencesStore, notifiers: [Notifier], dedupWindow: TimeInterval = 5) {
        self.modelContext = modelContext
        self.preferences = preferences
        self.dedup = Deduplicator(window: dedupWindow)
        self.notifiers = notifiers
        recomputeSummary()
    }

    var isSuppressed: Bool {
        doNotDisturb || preferences.isInQuietHours()
    }

    var menuBarState: MenuBarState {
        if hasActiveAttention { return .attention }
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
        lastKind = message.kind
        recomputeSummary()

        if message.kind.demandsAttention {
            lastAttentionAt = Date()
            scheduleAttentionExpiry()
        }
        refreshAttention()

        guard !isSuppressed else {
            PerchLog.bus.info("suppressed banner for \(message.kind.rawValue, privacy: .public)")
            return
        }

        let content = NotificationContent(from: message)
        for notifier in notifiers {
            notifier.deliver(content)
        }
    }

    /// Called when the user looks (opens the dashboard or menu, clicks the mascot or a banner):
    /// clears the active alert, marks waiting sessions as seen, and records the acknowledgement
    /// time on pending events so the stats can measure saved waiting.
    func acknowledge(at time: Date = .now) {
        let unseen = FetchDescriptor<AgentSession>(predicate: #Predicate { $0.acknowledgedAt == nil })
        if let sessions = try? modelContext.fetch(unseen) {
            for session in sessions where session.state == .waiting {
                session.acknowledgedAt = time
            }
        }

        let pending = FetchDescriptor<AgentEvent>(predicate: #Predicate { $0.acknowledgedAt == nil })
        if let events = try? modelContext.fetch(pending) {
            for event in events where event.isNotable {
                event.acknowledgedAt = time
            }
        }

        attentionExpiry?.cancel()
        hasActiveAttention = false
        save()
    }

    private func persist(_ message: RelayMessage) {
        let session = upsertSession(for: message)
        session.lastActivityAt = message.timestamp
        session.state = message.kind.resultingState
        if message.kind.demandsAttention {
            session.acknowledgedAt = nil
        }

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

    private var unseenAttentionCount: Int {
        let waiting = SessionState.waiting.rawValue
        let descriptor = FetchDescriptor<AgentSession>(
            predicate: #Predicate { $0.stateRaw == waiting && $0.acknowledgedAt == nil }
        )
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    private func refreshAttention() {
        hasActiveAttention = AttentionPolicy.isActive(
            unseenCount: unseenAttentionCount,
            lastAttentionAt: lastAttentionAt,
            now: Date(),
            ttl: attentionTTL
        )
    }

    private func scheduleAttentionExpiry() {
        attentionExpiry?.cancel()
        attentionExpiry = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(self.attentionTTL))
            guard !Task.isCancelled else { return }
            self.refreshAttention()
        }
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            PerchLog.bus.error("save failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
