import Foundation
import PerchCore

/// Registers the `perch_notify` MCP server in Cursor's `~/.cursor/mcp.json`, preserving any other
/// servers the user already has.
@MainActor
final class CursorIntegration: Integration {
    let id = "cursor"
    let title = "Cursor"
    let subtitle = "perch_notify MCP in ~/.cursor/mcp.json"
    let iconSystemName = "cursorarrow.rays"

    private let mcpName = PerchMCPServer.name

    private var cursorDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cursor", isDirectory: true)
    }

    var configURL: URL {
        cursorDirectory.appendingPathComponent("mcp.json", isDirectory: false)
    }

    var rulesSnippet: String? { PerchMCPServer.rulesSnippet }

    var plannedChange: String {
        let path = HelperLocator.helperURL?.path ?? "perch-helper"
        return "Registers the \"\(mcpName)\" MCP server:\n\(path) mcp"
    }

    func refreshStatus() -> IntegrationStatus {
        guard HelperLocator.isAvailable else { return .unavailable }
        guard FileManager.default.fileExists(atPath: cursorDirectory.path) else { return .notDetected }
        let data = try? Data(contentsOf: configURL)
        return MCPServerRegistrar.isRegistered(in: data, name: mcpName) ? .installed : .notInstalled
    }

    func install() throws -> IntegrationActionResult {
        guard let spec = PerchMCPServer.spec(source: .cursor) else {
            throw IntegrationError.helperMissing
        }
        try FileManager.default.createDirectory(at: cursorDirectory, withIntermediateDirectories: true)

        let data = try? Data(contentsOf: configURL)
        let backup = try ConfigBackup.backup(configURL)
        let updated = try MCPServerRegistrar.register(into: data, name: mcpName, spec: spec)
        try ConfigWriter.write(updated, to: configURL)

        PerchLog.integration.info("connected Cursor")
        return IntegrationActionResult(configURL: configURL, backupURL: backup)
    }

    func uninstall() throws -> IntegrationActionResult {
        let data = try? Data(contentsOf: configURL)
        let backup = try ConfigBackup.backup(configURL)
        let updated = try MCPServerRegistrar.unregister(from: data, name: mcpName)
        try ConfigWriter.write(updated, to: configURL)

        PerchLog.integration.info("disconnected Cursor")
        return IntegrationActionResult(configURL: configURL, backupURL: backup)
    }
}
