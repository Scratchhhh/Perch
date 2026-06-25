import Foundation

public enum ClaudeHookEvent: String, CaseIterable, Sendable {
    case stop = "Stop"
    case notification = "Notification"
    case permissionRequest = "PermissionRequest"
    case subagentStop = "SubagentStop"
}

public enum HookInstallStatus: String, Sendable {
    case notInstalled
    case partial
    case installed
}

/// Pure JSON surgery on a Claude Code `settings.json`. Foreign top-level keys and the user's own
/// hooks are always preserved; only Perch's own command entries are added or removed. Output is
/// deterministic (sorted keys, pretty printed) so backups diff cleanly.
public enum ClaudeSettingsEditor {

    public static func isPerchCommand(_ command: String) -> Bool {
        guard command.contains("perch-helper") else { return false }
        return command.range(of: "\\bhook\\b", options: .regularExpression) != nil
    }

    /// Adds (or refreshes) Perch's hook command for each event, stripping any previous Perch
    /// entry first so re-installing after the app moves doesn't leave stale paths.
    public static func install(into data: Data?, command: String, events: [String]) throws -> Data {
        let cleaned = try remove(from: data)
        var root = try object(from: cleaned)
        var hooks = (root["hooks"] as? [String: Any]) ?? [:]

        for event in events {
            var groups = (hooks[event] as? [[String: Any]]) ?? []
            groups.append([
                "matcher": "",
                "hooks": [["type": "command", "command": command]]
            ])
            hooks[event] = groups
        }

        root["hooks"] = hooks
        return try serialize(root)
    }

    /// Removes every Perch command entry, pruning groups and event arrays that become empty as a
    /// result. Anything that isn't a Perch entry is left exactly as it was.
    public static func remove(from data: Data?) throws -> Data {
        var root = try object(from: data)
        guard var hooks = root["hooks"] as? [String: Any] else {
            return try serialize(root)
        }

        for (event, value) in hooks {
            guard let groups = value as? [[String: Any]] else { continue }
            var keptGroups: [[String: Any]] = []

            for group in groups {
                guard let entries = group["hooks"] as? [[String: Any]] else {
                    keptGroups.append(group)
                    continue
                }
                let keptEntries = entries.filter { entry in
                    let command = entry["command"] as? String ?? ""
                    return !isPerchCommand(command)
                }
                if keptEntries.isEmpty {
                    continue
                }
                var updated = group
                updated["hooks"] = keptEntries
                keptGroups.append(updated)
            }

            if keptGroups.isEmpty {
                hooks.removeValue(forKey: event)
            } else {
                hooks[event] = keptGroups
            }
        }

        if hooks.isEmpty {
            root.removeValue(forKey: "hooks")
        } else {
            root["hooks"] = hooks
        }
        return try serialize(root)
    }

    public static func status(of data: Data?, events: [String]) -> HookInstallStatus {
        guard let root = try? object(from: data),
              let hooks = root["hooks"] as? [String: Any] else {
            return .notInstalled
        }

        let installedEvents = events.filter { event in
            guard let groups = hooks[event] as? [[String: Any]] else { return false }
            return groups.contains { group in
                guard let entries = group["hooks"] as? [[String: Any]] else { return false }
                return entries.contains { isPerchCommand($0["command"] as? String ?? "") }
            }
        }

        if installedEvents.isEmpty { return .notInstalled }
        if installedEvents.count == events.count { return .installed }
        return .partial
    }

    // MARK: - JSON helpers

    private static func object(from data: Data?) throws -> [String: Any] {
        guard let data, !data.isEmpty else { return [:] }
        let parsed = try JSONSerialization.jsonObject(with: data)
        guard let dictionary = parsed as? [String: Any] else {
            throw ClaudeSettingsError.notAnObject
        }
        return dictionary
    }

    private static func serialize(_ root: [String: Any]) throws -> Data {
        let data = try JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        return data + Data("\n".utf8)
    }
}

public enum ClaudeSettingsError: Error, Sendable {
    case notAnObject
}
