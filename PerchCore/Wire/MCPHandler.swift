import Foundation

/// Outcome of handling one JSON-RPC line: zero or one response line to write back, and an
/// optional `RelayMessage` to forward to the app.
public struct MCPResult: Sendable {
    public var responseLines: [Data]
    public var relay: RelayMessage?

    public init(responseLines: [Data] = [], relay: RelayMessage? = nil) {
        self.responseLines = responseLines
        self.relay = relay
    }
}

/// Minimal MCP server over JSON-RPC 2.0. Implements just enough of the protocol for Claude Code,
/// Cursor and Codex to discover and call the single `perch_notify` tool.
public final class MCPHandler {
    public let serverName: String
    public let serverVersion: String
    private let sessionId: String
    private var source: AgentSource
    private var negotiatedProtocol: String?

    public static let toolName = "perch_notify"

    public init(
        serverName: String = "perch",
        serverVersion: String = "1.0",
        sessionId: String = UUID().uuidString,
        source: AgentSource = .unknown
    ) {
        self.serverName = serverName
        self.serverVersion = serverVersion
        self.sessionId = sessionId
        self.source = source
    }

    public func handle(line: Data) -> MCPResult {
        guard let object = (try? JSONSerialization.jsonObject(with: line)) as? [String: Any] else {
            return single(error(id: NSNull(), code: -32700, message: "Parse error"))
        }
        guard let method = object["method"] as? String else {
            return MCPResult()
        }
        let id = object["id"]
        let params = object["params"] as? [String: Any] ?? [:]

        switch method {
        case "initialize":
            return single(handleInitialize(id: id, params: params))
        case "tools/list":
            return single(handleToolsList(id: id))
        case "tools/call":
            return handleToolsCall(id: id, params: params)
        case "ping":
            return single(result(id: id, result: [:]))
        default:
            if id == nil || method.hasPrefix("notifications/") {
                return MCPResult()
            }
            return single(error(id: id, code: -32601, message: "Method not found: \(method)"))
        }
    }

    // MARK: - Methods

    private func handleInitialize(id: Any?, params: [String: Any]) -> Data? {
        negotiatedProtocol = params["protocolVersion"] as? String
        if source == .unknown,
           let clientInfo = params["clientInfo"] as? [String: Any],
           let name = clientInfo["name"] as? String {
            source = MCPHandler.inferSource(fromClientName: name)
        }

        let payload: [String: Any] = [
            "protocolVersion": negotiatedProtocol ?? "2024-11-05",
            "capabilities": ["tools": [String: Any]()],
            "serverInfo": ["name": serverName, "version": serverVersion]
        ]
        return result(id: id, result: payload)
    }

    private func handleToolsList(id: Any?) -> Data? {
        let tool: [String: Any] = [
            "name": MCPHandler.toolName,
            "description": MCPHandler.toolDescription,
            "inputSchema": MCPHandler.inputSchema
        ]
        return result(id: id, result: ["tools": [tool]])
    }

    private func handleToolsCall(id: Any?, params: [String: Any]) -> MCPResult {
        guard let name = params["name"] as? String else {
            return single(error(id: id, code: -32602, message: "Missing tool name"))
        }
        guard name == MCPHandler.toolName else {
            return single(toolError(id: id, text: "Unknown tool: \(name)"))
        }

        let arguments = params["arguments"] as? [String: Any] ?? [:]
        let status = (arguments["status"] as? String) ?? "done"
        let message = (arguments["message"] as? String) ?? ""
        let project = (arguments["project"] as? String).flatMap { $0.isEmpty ? nil : $0 }

        let relay = RelayMessage(
            sessionId: sessionId,
            source: source,
            channel: .mcp,
            kind: MCPHandler.kind(forStatus: status),
            message: message,
            project: project
        )

        let payload: [String: Any] = [
            "content": [["type": "text", "text": "Perch was notified (\(status))."]],
            "isError": false
        ]
        return MCPResult(responseLines: [result(id: id, result: payload)].compactMap { $0 }, relay: relay)
    }

    // MARK: - Mapping

    public static func kind(forStatus status: String) -> EventKind {
        switch status.lowercased() {
        case "done": return .finished
        case "question": return .needsInput
        case "blocked": return .blocked
        default: return .finished
        }
    }

    static func inferSource(fromClientName name: String) -> AgentSource {
        let lowered = name.lowercased()
        if lowered.contains("claude") { return .claudeCode }
        if lowered.contains("cursor") { return .cursor }
        if lowered.contains("codex") { return .codex }
        return .unknown
    }

    // MARK: - JSON-RPC envelopes

    private func single(_ data: Data?) -> MCPResult {
        MCPResult(responseLines: [data].compactMap { $0 })
    }

    private func result(id: Any?, result: [String: Any]) -> Data? {
        encode(["jsonrpc": "2.0", "id": id ?? NSNull(), "result": result])
    }

    private func error(id: Any?, code: Int, message: String) -> Data? {
        encode(["jsonrpc": "2.0", "id": id ?? NSNull(), "error": ["code": code, "message": message]])
    }

    private func toolError(id: Any?, text: String) -> Data? {
        let payload: [String: Any] = [
            "content": [["type": "text", "text": text]],
            "isError": true
        ]
        return result(id: id, result: payload)
    }

    private func encode(_ object: [String: Any]) -> Data? {
        guard JSONSerialization.isValidJSONObject(object) else { return nil }
        return try? JSONSerialization.data(withJSONObject: object, options: [.withoutEscapingSlashes])
    }
}

extension MCPHandler {
    static let toolDescription = """
        Notify the user through Perch the moment you stop needing the terminal. Call this when you \
        finish a task (status "done"), when you need the user's input or a decision (status \
        "question"), or when you are blocked and cannot proceed (status "blocked"). Always include \
        a short, human-readable message describing what happened, and the project name when known. \
        Call it at the end of your work and whenever you would otherwise wait on the user.
        """

    static var inputSchema: [String: Any] {
        [
        "type": "object",
        "properties": [
            "status": [
                "type": "string",
                "enum": ["done", "question", "blocked"],
                "description": "done = task finished; question = you need input or a decision; blocked = you cannot continue."
            ],
            "message": [
                "type": "string",
                "description": "A short, human-readable summary of what happened or what you need."
            ],
            "project": [
                "type": "string",
                "description": "Optional project name or path so the user knows which work this refers to."
            ]
        ],
        "required": ["status", "message"]
        ]
    }
}
