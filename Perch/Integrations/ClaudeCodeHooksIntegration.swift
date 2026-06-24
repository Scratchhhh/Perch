import Foundation
import PerchCore

enum IntegrationError: LocalizedError {
    case helperMissing
    case notWritable(String)

    var errorDescription: String? {
        switch self {
        case .helperMissing:
            return "The bundled perch-helper could not be found inside the app."
        case .notWritable(let path):
            return "Could not write to \(path)."
        }
    }
}

/// Merges Perch's Stop / Notification / SubagentStop hooks into `~/.claude/settings.json`.
/// This is the channel that catches an agent blocking on a permission prompt.
@MainActor
final class ClaudeCodeHooksIntegration: Integration {
    let id = "claude-code"
    let title = "Claude Code"
    let subtitle = "Hooks in ~/.claude/settings.json"
    let iconSystemName = "terminal"

    private let events = ClaudeHookEvent.allCases.map(\.rawValue)

    private var claudeDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude", isDirectory: true)
    }

    var configURL: URL {
        claudeDirectory.appendingPathComponent("settings.json", isDirectory: false)
    }

    var plannedChange: String {
        let command = HelperLocator.shellCommand(subcommand: "hook") ?? "perch-helper hook"
        return "Adds \(events.joined(separator: ", ")) hooks that run:\n\(command)"
    }

    func refreshStatus() -> IntegrationStatus {
        guard HelperLocator.isAvailable else { return .unavailable }
        guard FileManager.default.fileExists(atPath: claudeDirectory.path) else { return .notDetected }

        let data = try? Data(contentsOf: configURL)
        switch ClaudeSettingsEditor.status(of: data, events: events) {
        case .notInstalled: return .notInstalled
        case .partial: return .partiallyInstalled
        case .installed: return .installed
        }
    }

    func install() throws -> IntegrationActionResult {
        guard let command = HelperLocator.shellCommand(subcommand: "hook") else {
            throw IntegrationError.helperMissing
        }
        try FileManager.default.createDirectory(at: claudeDirectory, withIntermediateDirectories: true)

        let current = try? Data(contentsOf: configURL)
        let backup = try ConfigBackup.backup(configURL)
        let updated = try ClaudeSettingsEditor.install(into: current, command: command, events: events)
        try write(updated)

        PerchLog.integration.info("installed Claude Code hooks")
        return IntegrationActionResult(configURL: configURL, backupURL: backup)
    }

    func uninstall() throws -> IntegrationActionResult {
        let current = try? Data(contentsOf: configURL)
        let backup = try ConfigBackup.backup(configURL)
        let updated = try ClaudeSettingsEditor.remove(from: current)
        try write(updated)

        PerchLog.integration.info("removed Claude Code hooks")
        return IntegrationActionResult(configURL: configURL, backupURL: backup)
    }

    private func write(_ data: Data) throws {
        do {
            try data.write(to: configURL, options: .atomic)
        } catch {
            throw IntegrationError.notWritable(configURL.path)
        }
    }
}
