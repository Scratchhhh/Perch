import Foundation
import PerchCore

/// Registers the `perch_notify` MCP server in Codex's `~/.codex/config.toml` via a block-level
/// edit, leaving the rest of the (often large) TOML untouched.
@MainActor
final class CodexIntegration: Integration {
    let id = "codex"
    let title = "Codex"
    let subtitle = "perch_notify MCP in ~/.codex/config.toml"
    let iconSystemName = "chevron.left.forwardslash.chevron.right"

    private let mcpName = PerchMCPServer.name

    private var codexDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex", isDirectory: true)
    }

    var configURL: URL {
        codexDirectory.appendingPathComponent("config.toml", isDirectory: false)
    }

    var rulesSnippet: String? { PerchMCPServer.rulesSnippet }

    var plannedChange: String {
        let path = HelperLocator.helperURL?.path ?? "perch-helper"
        return "Adds a [mcp_servers.\(mcpName)] block:\n\(path) mcp"
    }

    func refreshStatus() -> IntegrationStatus {
        guard HelperLocator.isAvailable else { return .unavailable }
        guard FileManager.default.fileExists(atPath: codexDirectory.path) else { return .notDetected }
        let text = (try? String(contentsOf: configURL, encoding: .utf8)) ?? ""
        return TomlMCPEditor.isRegistered(in: text, name: mcpName) ? .installed : .notInstalled
    }

    func install() throws -> IntegrationActionResult {
        guard let spec = PerchMCPServer.spec(source: .codex) else {
            throw IntegrationError.helperMissing
        }
        try FileManager.default.createDirectory(at: codexDirectory, withIntermediateDirectories: true)

        let text = (try? String(contentsOf: configURL, encoding: .utf8)) ?? ""
        let backup = try ConfigBackup.backup(configURL)
        let updated = TomlMCPEditor.register(into: text, name: mcpName, spec: spec)
        try ConfigWriter.write(Data(updated.utf8), to: configURL)

        PerchLog.integration.info("connected Codex")
        return IntegrationActionResult(configURL: configURL, backupURL: backup)
    }

    func uninstall() throws -> IntegrationActionResult {
        let text = (try? String(contentsOf: configURL, encoding: .utf8)) ?? ""
        let backup = try ConfigBackup.backup(configURL)
        let updated = TomlMCPEditor.unregister(from: text, name: mcpName)
        try ConfigWriter.write(Data(updated.utf8), to: configURL)

        PerchLog.integration.info("disconnected Codex")
        return IntegrationActionResult(configURL: configURL, backupURL: backup)
    }
}
