import Foundation

/// Runs the stdio MCP server. Reads newline-delimited JSON-RPC from stdin, answers on stdout, and
/// relays any `perch_notify` call to the app. Stays alive until stdin closes.
enum MCPCommand {
    static func run() -> Int32 {
        let handler = MCPHandler(
            serverName: "perch",
            serverVersion: "1.0",
            sessionId: UUID().uuidString,
            source: resolveSource()
        )
        let stdout = FileHandle.standardOutput
        let newline = Data("\n".utf8)

        while let line = readLine(strippingNewline: true) {
            if line.isEmpty { continue }
            let outcome = handler.handle(line: Data(line.utf8))

            for response in outcome.responseLines {
                stdout.write(response)
                stdout.write(newline)
            }
            if let relay = outcome.relay {
                try? RelayClient.send(relay, timeout: 1.5)
            }
        }
        return 0
    }

    private static func resolveSource() -> AgentSource {
        if let raw = ProcessInfo.processInfo.environment["PERCH_SOURCE"],
           let source = AgentSource(rawValue: raw) {
            return source
        }
        return .unknown
    }
}
