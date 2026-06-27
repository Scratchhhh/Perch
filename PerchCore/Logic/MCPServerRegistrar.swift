import Foundation

public struct MCPServerSpec: Sendable, Equatable {
    public var type: String?
    public var command: String
    public var args: [String]
    public var env: [String: String]

    public init(type: String? = "stdio", command: String, args: [String], env: [String: String] = [:]) {
        self.type = type
        self.command = command
        self.args = args
        self.env = env
    }

    var jsonObject: [String: Any] {
        var object: [String: Any] = ["command": command, "args": args]
        if let type { object["type"] = type }
        if !env.isEmpty { object["env"] = env }
        return object
    }
}

/// Adds or removes a single named server inside a JSON config that uses an `mcpServers` object
/// (Claude Code's `~/.claude.json`, Cursor's `mcp.json`). Every other key and server is preserved.
public enum MCPServerRegistrar {
    public static func register(into data: Data?, name: String, spec: MCPServerSpec, key: String = "mcpServers") throws -> Data {
        var root = try object(from: data)
        var servers = (root[key] as? [String: Any]) ?? [:]
        servers[name] = spec.jsonObject
        root[key] = servers
        return try serialize(root)
    }

    public static func unregister(from data: Data?, name: String, key: String = "mcpServers") throws -> Data {
        var root = try object(from: data)
        guard var servers = root[key] as? [String: Any] else {
            return try serialize(root)
        }
        servers.removeValue(forKey: name)
        root[key] = servers
        return try serialize(root)
    }

    public static func isRegistered(in data: Data?, name: String, key: String = "mcpServers") -> Bool {
        guard let root = try? object(from: data),
              let servers = root[key] as? [String: Any] else {
            return false
        }
        return servers[name] != nil
    }

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
