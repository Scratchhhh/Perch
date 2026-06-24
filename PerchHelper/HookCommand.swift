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
        let message = (object["message"] as? String) ?? ""

        let relay = RelayMessage(
            sessionId: sessionId,
            source: .claudeCode,
            channel: .hook,
            kind: kind(forEvent: eventName),
            message: message,
            project: cwd,
            transcriptPath: transcript
        )

        do {
            try RelayClient.send(relay)
        } catch {
            FileHandle.standardError.write(Data("perch-helper hook: relay failed: \(error)\n".utf8))
        }
        return 0
    }

    static func kind(forEvent eventName: String) -> EventKind {
        switch eventName {
        case "Stop":
            return .finished
        case "SubagentStop":
            return .subagentDone
        case "Notification":
            return .needsInput
        case "PermissionRequest", "PreToolUse":
            return .permission
        default:
            return .finished
        }
    }
}
