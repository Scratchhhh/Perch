import Foundation

public struct TranscriptSignal: Sendable, Equatable {
    public let sessionId: String
    public let cwd: String?
    public let kind: EventKind
    public let timestamp: Date?

    public init(sessionId: String, cwd: String?, kind: EventKind, timestamp: Date?) {
        self.sessionId = sessionId
        self.cwd = cwd
        self.kind = kind
        self.timestamp = timestamp
    }
}

/// Reads one transcript line and decides whether it represents the agent stopping its turn (the
/// passive "looks finished / waiting" signal). Everything else — tool calls, user messages,
/// sidechain/subagent traffic — is ignored so the file watcher stays quiet while work is ongoing.
public enum TranscriptParser {
    public static func signal(forLine data: Data) -> TranscriptSignal? {
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return nil
        }
        guard (object["type"] as? String) == "assistant" else { return nil }
        if (object["isSidechain"] as? Bool) == true { return nil }
        guard let sessionId = object["sessionId"] as? String, !sessionId.isEmpty else { return nil }
        guard let message = object["message"] as? [String: Any],
              let stopReason = message["stop_reason"] as? String,
              stopReason == "end_turn" || stopReason == "stop_sequence" else {
            return nil
        }

        let cwd = object["cwd"] as? String
        let timestamp = (object["timestamp"] as? String).flatMap(parseDate)
        return TranscriptSignal(sessionId: sessionId, cwd: cwd, kind: .finished, timestamp: timestamp)
    }

    private static func parseDate(_ string: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: string) { return date }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: string)
    }
}
