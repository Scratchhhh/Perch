import Foundation
import PerchCore

/// Describes how Perch's MCP server is registered with each tool, plus the optional prompt snippet
/// we offer for environments without hooks.
enum PerchMCPServer {
    static let name = "perch"

    static func spec(source: AgentSource) -> MCPServerSpec? {
        guard let path = HelperLocator.helperURL?.path else { return nil }
        return MCPServerSpec(
            type: "stdio",
            command: path,
            args: ["mcp"],
            env: ["PERCH_SOURCE": source.rawValue]
        )
    }

    static let rulesSnippet = """
        When you finish a task, call the perch_notify tool with status "done" and a one-line summary. \
        When you need my input, a decision, or permission, call perch_notify with status "question" \
        (or "blocked" if you cannot continue). Include the project name when you know it.
        """
}
