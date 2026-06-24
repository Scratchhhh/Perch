import Foundation

/// Surgical, block-level edits to Codex's `config.toml`. We never reparse or rewrite the whole
/// document (it holds the user's models, projects and plugins); we only insert or remove our own
/// `[mcp_servers.<name>]` table, leaving every other byte intact.
public enum TomlMCPEditor {
    public static func register(into text: String, name: String, spec: MCPServerSpec) -> String {
        let withoutOurs = removeBlock(from: text, name: name)
        let block = makeBlock(name: name, spec: spec)

        var base = withoutOurs
        if !base.isEmpty && !base.hasSuffix("\n") {
            base += "\n"
        }
        if !base.isEmpty && !base.hasSuffix("\n\n") {
            base += "\n"
        }
        return base + block
    }

    public static func unregister(from text: String, name: String) -> String {
        removeBlock(from: text, name: name)
    }

    public static func isRegistered(in text: String, name: String) -> Bool {
        header(for: name, in: text) != nil
    }

    // MARK: - Internals

    private static func header(for name: String, in text: String) -> Int? {
        let target = "[mcp_servers.\(name)]"
        let lines = text.components(separatedBy: "\n")
        for (index, line) in lines.enumerated() where line.trimmingCharacters(in: .whitespaces) == target {
            return index
        }
        return nil
    }

    private static func removeBlock(from text: String, name: String) -> String {
        let target = "[mcp_servers.\(name)]"
        var lines = text.components(separatedBy: "\n")

        guard let start = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == target }) else {
            return text
        }

        var end = start + 1
        while end < lines.count {
            let trimmed = lines[end].trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("[") {
                break
            }
            end += 1
        }

        lines.removeSubrange(start..<end)

        // Collapse a blank line we likely left behind so repeated edits don't accrete whitespace.
        if start > 0, start < lines.count,
           lines[start - 1].trimmingCharacters(in: .whitespaces).isEmpty,
           lines[start].trimmingCharacters(in: .whitespaces).isEmpty {
            lines.remove(at: start)
        }

        var joined = lines.joined(separator: "\n")
        while joined.hasSuffix("\n\n") {
            joined.removeLast()
        }
        return joined
    }

    private static func makeBlock(name: String, spec: MCPServerSpec) -> String {
        var block = "[mcp_servers.\(name)]\n"
        block += "command = \(quoted(spec.command))\n"
        block += "args = [\(spec.args.map(quoted).joined(separator: ", "))]\n"
        if !spec.env.isEmpty {
            let pairs = spec.env
                .sorted { $0.key < $1.key }
                .map { "\(quoted($0.key)) = \(quoted($0.value))" }
                .joined(separator: ", ")
            block += "env = { \(pairs) }\n"
        }
        return block
    }

    private static func quoted(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}
