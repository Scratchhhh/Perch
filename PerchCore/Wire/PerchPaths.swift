import Foundation

public enum PerchPathError: Error, Sendable {
    case invalidPort(String)
    case missingToken
}

/// Resolved location of the running app's local listener.
public struct ListenerEndpoint: Sendable {
    public let port: UInt16
    public let token: String

    public init(port: UInt16, token: String) {
        self.port = port
        self.token = token
    }
}

/// Shared filesystem layout for app <-> helper coordination.
/// Everything lives under Application Support so both processes resolve it the same way.
public enum PerchPaths {
    public static let directoryName = "Perch"

    public static var supportDirectory: URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support", isDirectory: true)
        return base.appendingPathComponent(directoryName, isDirectory: true)
    }

    public static var portFile: URL {
        supportDirectory.appendingPathComponent("port", isDirectory: false)
    }

    public static var tokenFile: URL {
        supportDirectory.appendingPathComponent("token", isDirectory: false)
    }

    public static var logsDirectory: URL {
        supportDirectory.appendingPathComponent("Logs", isDirectory: true)
    }

    public static func ensureSupportDirectory() throws {
        try FileManager.default.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
    }

    /// Reads the port/token pair written by the app. Used by the helper to reach the listener.
    public static func readEndpoint() throws -> ListenerEndpoint {
        let rawPort = try String(contentsOf: portFile, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let port = UInt16(rawPort) else {
            throw PerchPathError.invalidPort(rawPort)
        }
        let token = try String(contentsOf: tokenFile, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            throw PerchPathError.missingToken
        }
        return ListenerEndpoint(port: port, token: token)
    }
}
