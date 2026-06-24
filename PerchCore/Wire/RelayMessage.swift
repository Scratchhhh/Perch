import Foundation

/// A single notification signal travelling from a provider channel into the app.
/// This is the on-the-wire contract between `perch-helper` and the running app,
/// so every field is value-typed and Codable.
public struct RelayMessage: Codable, Sendable, Equatable {
    public var sessionId: String
    public var source: AgentSource
    public var channel: EventChannel
    public var kind: EventKind
    public var message: String
    public var project: String?
    public var transcriptPath: String?
    public var timestamp: Date

    public init(
        sessionId: String,
        source: AgentSource,
        channel: EventChannel,
        kind: EventKind,
        message: String,
        project: String? = nil,
        transcriptPath: String? = nil,
        timestamp: Date = Date()
    ) {
        self.sessionId = sessionId
        self.source = source
        self.channel = channel
        self.kind = kind
        self.message = message
        self.project = project
        self.transcriptPath = transcriptPath
        self.timestamp = timestamp
    }
}

/// What actually crosses the socket: a token for authentication plus the payload.
public struct RelayEnvelope: Codable, Sendable {
    public var token: String
    public var message: RelayMessage

    public init(token: String, message: RelayMessage) {
        self.token = token
        self.message = message
    }
}

public enum PerchJSON {
    public static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    public static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
