import Foundation

/// One notification's worth of information, reduced to just what coalescing needs.
public struct PendingNotice: Sendable, Equatable {
    public let sessionId: String
    public let kind: EventKind
    public let projectName: String

    public init(sessionId: String, kind: EventKind, projectName: String) {
        self.sessionId = sessionId
        self.kind = kind
        self.projectName = projectName
    }
}

/// The single banner a burst of notices collapses into.
public struct CoalescedSummary: Sendable, Equatable {
    public let title: String
    public let body: String
    /// A representative kind so the caller can pick the right category/sound (attention wins).
    public let primaryKind: EventKind
    public let count: Int

    public init(title: String, body: String, primaryKind: EventKind, count: Int) {
        self.title = title
        self.body = body
        self.primaryKind = primaryKind
        self.count = count
    }
}

/// Collapses a burst of near-simultaneous notifications into one summary, so three agents finishing
/// at once produces "3 agents finished" instead of three separate banners. The timing/window lives
/// in the app (`EventBus`); this type owns the pure grouping and wording so it can be tested.
public enum NotificationCoalescer {
    /// Notices arriving within this window of the first are batched into one summary.
    public static let window: TimeInterval = 1.8

    public static func summarize(_ notices: [PendingNotice]) -> CoalescedSummary? {
        guard let first = notices.first else { return nil }
        let total = notices.count

        let attention = notices.filter { $0.kind.demandsAttention }
        let finished = notices.filter { $0.kind == .finished }
        let info = notices.filter { !$0.kind.demandsAttention && $0.kind != .finished }

        let activeBuckets = [attention.count, finished.count, info.count].filter { $0 > 0 }.count

        let title: String
        let body: String
        if activeBuckets <= 1 {
            // A single category: name the action once and list the projects involved.
            if !attention.isEmpty {
                title = total == 1 ? "1 agent needs you" : "\(total) agents need you"
            } else if !finished.isEmpty {
                title = total == 1 ? "1 agent finished" : "\(total) agents finished"
            } else {
                title = total == 1 ? "1 agent update" : "\(total) agent updates"
            }
            body = projectList(notices.map(\.projectName))
        } else {
            // Mixed bag: a short breakdown reads better than a project list.
            title = "\(total) agent updates"
            var parts: [String] = []
            if !attention.isEmpty { parts.append("\(attention.count) need you") }
            if !finished.isEmpty { parts.append("\(finished.count) finished") }
            if !info.isEmpty { parts.append("\(info.count) other") }
            body = parts.joined(separator: " · ")
        }

        let primaryKind = attention.first?.kind ?? (finished.first?.kind ?? first.kind)
        return CoalescedSummary(title: title, body: body, primaryKind: primaryKind, count: total)
    }

    /// Comma-joined unique project names, abbreviated past three so the banner stays short.
    private static func projectList(_ names: [String], max: Int = 3) -> String {
        var seen = Set<String>()
        let unique = names.filter { seen.insert($0).inserted }
        guard unique.count > max else { return unique.joined(separator: ", ") }
        let shown = unique.prefix(max).joined(separator: ", ")
        return "\(shown) +\(unique.count - max) more"
    }
}
