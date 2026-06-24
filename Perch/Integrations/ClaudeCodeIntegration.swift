import Foundation
import PerchCore

/// Connects Claude Code through two channels: Stop/Notification/SubagentStop hooks in
/// `settings.json`, and the `perch_notify` MCP server in `~/.claude.json`. Hooks are the reliable
/// path (they catch permission blocks); MCP is there for parity with the other tools.
@MainActor
final class ClaudeCodeIntegration: Integration {
    let id = "claude-code"
    let title = "Claude Code"
    let subtitle = "Hooks + perch_notify MCP"
    let iconSystemName = "terminal"

    private let events = ClaudeHookEvent.allCases.map(\.rawValue)
    private let mcpName = PerchMCPServer.name

    private var home: URL { FileManager.default.homeDirectoryForCurrentUser }
    private var claudeDirectory: URL { home.appendingPathComponent(".claude", isDirectory: true) }
    private var mcpConfigURL: URL { home.appendingPathComponent(".claude.json", isDirectory: false) }

    var configURL: URL {
        claudeDirectory.appendingPathComponent("settings.json", isDirectory: false)
    }

    var plannedChange: String {
        let hook = HelperLocator.shellCommand(subcommand: "hook") ?? "perch-helper hook"
        let mcp = HelperLocator.helperURL?.path ?? "perch-helper"
        return """
            settings.json: \(events.joined(separator: ", ")) hooks running
            \(hook)

            ~/.claude.json: registers the \"\(mcpName)\" MCP server
            \(mcp) mcp
            """
    }

    func refreshStatus() -> IntegrationStatus {
        guard HelperLocator.isAvailable else { return .unavailable }
        guard FileManager.default.fileExists(atPath: claudeDirectory.path) else { return .notDetected }

        let hooksData = try? Data(contentsOf: configURL)
        let hooksOn = ClaudeSettingsEditor.status(of: hooksData, events: events) == .installed

        let mcpData = try? Data(contentsOf: mcpConfigURL)
        let mcpOn = MCPServerRegistrar.isRegistered(in: mcpData, name: mcpName)

        switch (hooksOn, mcpOn) {
        case (true, true): return .installed
        case (false, false): return .notInstalled
        default: return .partiallyInstalled
        }
    }

    func install() throws -> IntegrationActionResult {
        guard let hookCommand = HelperLocator.shellCommand(subcommand: "hook"),
              let spec = PerchMCPServer.spec(source: .claudeCode) else {
            throw IntegrationError.helperMissing
        }
        try FileManager.default.createDirectory(at: claudeDirectory, withIntermediateDirectories: true)

        let hooksData = try? Data(contentsOf: configURL)
        let backup = try ConfigBackup.backup(configURL)
        let updatedHooks = try ClaudeSettingsEditor.install(into: hooksData, command: hookCommand, events: events)
        try ConfigWriter.write(updatedHooks, to: configURL)

        try registerMCP(spec)

        PerchLog.integration.info("connected Claude Code (hooks + mcp)")
        return IntegrationActionResult(configURL: configURL, backupURL: backup)
    }

    func uninstall() throws -> IntegrationActionResult {
        let hooksData = try? Data(contentsOf: configURL)
        let backup = try ConfigBackup.backup(configURL)
        let updatedHooks = try ClaudeSettingsEditor.remove(from: hooksData)
        try ConfigWriter.write(updatedHooks, to: configURL)

        if FileManager.default.fileExists(atPath: mcpConfigURL.path) {
            let mcpData = try? Data(contentsOf: mcpConfigURL)
            try ConfigBackup.backup(mcpConfigURL)
            let updated = try MCPServerRegistrar.unregister(from: mcpData, name: mcpName)
            try ConfigWriter.write(updated, to: mcpConfigURL, posixPermissions: 0o600)
        }

        PerchLog.integration.info("disconnected Claude Code")
        return IntegrationActionResult(configURL: configURL, backupURL: backup)
    }

    private func registerMCP(_ spec: MCPServerSpec) throws {
        let mcpData = try? Data(contentsOf: mcpConfigURL)
        try ConfigBackup.backup(mcpConfigURL)
        let updated = try MCPServerRegistrar.register(into: mcpData, name: mcpName, spec: spec)
        // ~/.claude.json holds the OAuth account, so keep it owner-only.
        try ConfigWriter.write(updated, to: mcpConfigURL, posixPermissions: 0o600)
    }
}
