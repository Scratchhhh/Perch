import Foundation

enum IntegrationStatus: Sendable, Equatable {
    case notDetected
    case notInstalled
    case partiallyInstalled
    case installed
    case unavailable

    var label: String {
        switch self {
        case .notDetected: return "Not detected"
        case .notInstalled: return "Not connected"
        case .partiallyInstalled: return "Partially connected"
        case .installed: return "Connected"
        case .unavailable: return "Unavailable"
        }
    }
}

struct IntegrationActionResult: Sendable {
    let configURL: URL
    let backupURL: URL?
}

/// One connectable tool (Claude Code, Cursor, Codex…). Every implementation edits a third-party
/// config idempotently and always backs it up first.
@MainActor
protocol Integration: AnyObject, Identifiable {
    var id: String { get }
    var title: String { get }
    var subtitle: String { get }
    var iconSystemName: String { get }
    var configURL: URL { get }

    /// A short, human-readable description of exactly what `install()` will write.
    var plannedChange: String { get }

    func refreshStatus() -> IntegrationStatus
    func install() throws -> IntegrationActionResult
    func uninstall() throws -> IntegrationActionResult
}
