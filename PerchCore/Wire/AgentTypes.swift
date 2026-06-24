import Foundation

public enum AgentSource: String, Codable, Sendable, CaseIterable {
    case claudeCode
    case cursor
    case codex
    case unknown

    public var displayName: String {
        switch self {
        case .claudeCode: return "Claude Code"
        case .cursor: return "Cursor"
        case .codex: return "Codex"
        case .unknown: return "Agent"
        }
    }
}

public enum EventChannel: String, Codable, Sendable, CaseIterable {
    case mcp
    case hook
    case filewatch
    case test
}

public enum EventKind: String, Codable, Sendable, CaseIterable {
    case started
    case finished
    case needsInput
    case permission
    case subagentDone
    case blocked

    public var resultingState: SessionState {
        switch self {
        case .started, .subagentDone:
            return .working
        case .finished:
            return .done
        case .needsInput, .permission, .blocked:
            return .waiting
        }
    }

    public var demandsAttention: Bool {
        switch self {
        case .needsInput, .permission, .blocked:
            return true
        case .started, .finished, .subagentDone:
            return false
        }
    }
}

public enum SessionState: String, Codable, Sendable, CaseIterable {
    case working
    case waiting
    case done
    case idle
}
