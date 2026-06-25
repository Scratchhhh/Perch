import Foundation

/// Reads a Claude Code hook payload from stdin and relays it to the running app.
/// Always exits 0 so a failed relay never disrupts the agent that invoked the hook.
enum HookCommand {
    static func run() -> Int32 {
        let input = FileHandle.standardInput.readDataToEndOfFile()
        guard !input.isEmpty,
              let object = (try? JSONSerialization.jsonObject(with: input)) as? [String: Any] else {
            FileHandle.standardError.write(Data("perch-helper hook: could not parse stdin JSON\n".utf8))
            return 0
        }

        let eventName = (object["hook_event_name"] as? String) ?? "Stop"
        let sessionId = (object["session_id"] as? String) ?? "unknown"
        let transcript = object["transcript_path"] as? String
        let cwd = object["cwd"] as? String

        let relay = RelayMessage(
            sessionId: sessionId,
            source: .claudeCode,
            channel: .hook,
            kind: kind(forEvent: eventName),
            message: message(forEvent: eventName, payload: object),
            project: cwd,
            transcriptPath: transcript
        )

        do {
            // Short timeout: a PermissionRequest hook runs in front of the prompt, so it must
            // never stall it. We also write nothing to stdout, so the permission decision is
            // left entirely to Claude Code.
            try RelayClient.send(relay, timeout: 1.5)
        } catch {
            FileHandle.standardError.write(Data("perch-helper hook: relay failed: \(error)\n".utf8))
        }
        return 0
    }

    static func kind(forEvent eventName: String) -> EventKind {
        EventKind.fromClaudeHookEvent(eventName)
    }

    static func message(forEvent eventName: String, payload: [String: Any]) -> String {
        if eventName == "PermissionRequest" {
            let tool = (payload["tool_name"] as? String) ?? "a tool"
            let detail = toolDetail(payload["tool_input"])
            return detail.isEmpty ? "Allow \(tool)?" : "Allow \(tool): \(detail)"
        }
        return (payload["message"] as? String) ?? ""
    }

    private static func toolDetail(_ input: Any?) -> String {
        guard let dictionary = input as? [String: Any] else { return "" }
        for key in ["command", "file_path", "path", "url", "pattern", "query"] {
            if let value = dictionary[key] as? String, !value.isEmpty {
                return String(value.prefix(80))
            }
        }
        return ""
    }
}
