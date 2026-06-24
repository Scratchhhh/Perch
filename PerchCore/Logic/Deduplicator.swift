import Foundation

public struct DedupKey: Hashable, Sendable {
    public let sessionId: String
    public let kind: EventKind

    public init(sessionId: String, kind: EventKind) {
        self.sessionId = sessionId
        self.kind = kind
    }
}

/// Collapses the same (session, kind) signal arriving from several channels within a short window.
/// A "done" can show up via MCP, a Stop hook and the file watcher almost simultaneously; the user
/// should only be notified once.
public final class Deduplicator: @unchecked Sendable {
    private let window: TimeInterval
    private var lastSeen: [DedupKey: Date] = [:]
    private let lock = NSLock()

    public init(window: TimeInterval = 5) {
        self.window = window
    }

    /// Returns `true` if the event is novel and should be processed, `false` if it is a duplicate
    /// of one already seen inside the window.
    public func shouldProcess(sessionId: String, kind: EventKind, at time: Date = Date()) -> Bool {
        let key = DedupKey(sessionId: sessionId, kind: kind)
        lock.lock()
        defer { lock.unlock() }

        if let previous = lastSeen[key], time.timeIntervalSince(previous) < window, time >= previous {
            return false
        }
        lastSeen[key] = time
        return true
    }

    public func reset() {
        lock.lock()
        lastSeen.removeAll()
        lock.unlock()
    }
}
