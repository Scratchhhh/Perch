import XCTest
@testable import PerchCore

final class SettingsMergeTests: XCTestCase {
    private let events = ClaudeHookEvent.allCases.map(\.rawValue)
    private let command = "\"/Applications/Perch.app/Contents/Helpers/perch-helper\" hook"

    private func object(_ data: Data) throws -> [String: Any] {
        let parsed = try JSONSerialization.jsonObject(with: data)
        return try XCTUnwrap(parsed as? [String: Any])
    }

    private func commands(in data: Data, event: String) throws -> [String] {
        let root = try object(data)
        let hooks = try XCTUnwrap(root["hooks"] as? [String: Any])
        let groups = (hooks[event] as? [[String: Any]]) ?? []
        return groups.flatMap { group in
            (group["hooks"] as? [[String: Any]])?.compactMap { $0["command"] as? String } ?? []
        }
    }

    func testInstallPreservesForeignKeys() throws {
        let original = Data(#"{"theme":"dark","includeCoAuthoredBy":false}"#.utf8)
        let result = try ClaudeSettingsEditor.install(into: original, command: command, events: events)
        let root = try object(result)

        XCTAssertEqual(root["theme"] as? String, "dark")
        XCTAssertEqual(root["includeCoAuthoredBy"] as? Bool, false)
        XCTAssertNotNil(root["hooks"])
    }

    func testInstallAddsAllEvents() throws {
        let result = try ClaudeSettingsEditor.install(into: nil, command: command, events: events)
        for event in events {
            XCTAssertTrue(try commands(in: result, event: event).contains(command), "missing \(event)")
        }
    }

    func testInstallIsIdempotent() throws {
        let once = try ClaudeSettingsEditor.install(into: nil, command: command, events: events)
        let twice = try ClaudeSettingsEditor.install(into: once, command: command, events: events)

        XCTAssertEqual(once, twice)
        for event in events {
            XCTAssertEqual(try commands(in: twice, event: event).filter { $0 == command }.count, 1)
        }
    }

    func testReinstallReplacesStalePath() throws {
        let old = "\"/old/location/perch-helper\" hook"
        let first = try ClaudeSettingsEditor.install(into: nil, command: old, events: events)
        let second = try ClaudeSettingsEditor.install(into: first, command: command, events: events)

        for event in events {
            let found = try commands(in: second, event: event)
            XCTAssertTrue(found.contains(command))
            XCTAssertFalse(found.contains(old), "stale path should be gone from \(event)")
        }
    }

    func testInstallKeepsUserHookOnSameEvent() throws {
        let userHook = #"{"hooks":{"Stop":[{"matcher":"","hooks":[{"type":"command","command":"/usr/bin/say done"}]}]}}"#
        let result = try ClaudeSettingsEditor.install(into: Data(userHook.utf8), command: command, events: events)

        let stopCommands = try commands(in: result, event: "Stop")
        XCTAssertTrue(stopCommands.contains("/usr/bin/say done"))
        XCTAssertTrue(stopCommands.contains(command))
    }

    func testRemoveStripsOnlyPerchAndPrunes() throws {
        let userHook = #"{"theme":"light","hooks":{"Stop":[{"matcher":"","hooks":[{"type":"command","command":"/usr/bin/say done"}]}]}}"#
        let installed = try ClaudeSettingsEditor.install(into: Data(userHook.utf8), command: command, events: events)
        let removed = try ClaudeSettingsEditor.remove(from: installed)
        let root = try object(removed)

        XCTAssertEqual(root["theme"] as? String, "light")
        let stopCommands = try commands(in: removed, event: "Stop")
        XCTAssertEqual(stopCommands, ["/usr/bin/say done"])

        // Notification/SubagentStop were created only by us, so they should be gone entirely.
        let hooks = try XCTUnwrap(root["hooks"] as? [String: Any])
        XCTAssertNil(hooks["Notification"])
        XCTAssertNil(hooks["SubagentStop"])
    }

    func testRemoveDropsHooksKeyWhenEmpty() throws {
        let installed = try ClaudeSettingsEditor.install(into: Data(#"{"theme":"dark"}"#.utf8), command: command, events: events)
        let removed = try ClaudeSettingsEditor.remove(from: installed)
        let root = try object(removed)

        XCTAssertNil(root["hooks"])
        XCTAssertEqual(root["theme"] as? String, "dark")
    }

    func testStatusReporting() throws {
        XCTAssertEqual(ClaudeSettingsEditor.status(of: nil, events: events), .notInstalled)

        let installed = try ClaudeSettingsEditor.install(into: nil, command: command, events: events)
        XCTAssertEqual(ClaudeSettingsEditor.status(of: installed, events: events), .installed)

        let partial = try ClaudeSettingsEditor.install(into: nil, command: command, events: ["Stop"])
        XCTAssertEqual(ClaudeSettingsEditor.status(of: partial, events: events), .partial)
    }

    func testRemoveOnPristineSettingsIsSafe() throws {
        // Removing from settings that never had Perch leaves the document semantically intact.
        let original = Data(#"{"theme":"dark","includeCoAuthoredBy":false}"#.utf8)
        let removed = try ClaudeSettingsEditor.remove(from: original)
        let root = try object(removed)
        XCTAssertEqual(root["theme"] as? String, "dark")
        XCTAssertEqual(root["includeCoAuthoredBy"] as? Bool, false)
    }
}
