import Foundation
import SwiftData
import PerchCore

@Model
final class AgentEvent {
    @Attribute(.unique) var id: UUID
    var ts: Date
    var sourceRaw: String
    var channelRaw: String
    var kindRaw: String
    var message: String
    var transcriptPath: String?
    var acknowledgedAt: Date?
    var session: AgentSession?

    init(
        id: UUID = UUID(),
        ts: Date = .now,
        source: AgentSource,
        channel: EventChannel,
        kind: EventKind,
        message: String,
        transcriptPath: String? = nil
    ) {
        self.id = id
        self.ts = ts
        self.sourceRaw = source.rawValue
        self.channelRaw = channel.rawValue
        self.kindRaw = kind.rawValue
        self.message = message
        self.transcriptPath = transcriptPath
    }

    /// Events that would otherwise have kept the user waiting at the terminal.
    var isNotable: Bool {
        kind == .finished || kind.demandsAttention
    }

    var source: AgentSource {
        AgentSource(rawValue: sourceRaw) ?? .unknown
    }

    var channel: EventChannel {
        EventChannel(rawValue: channelRaw) ?? .test
    }

    var kind: EventKind {
        EventKind(rawValue: kindRaw) ?? .finished
    }
}
