import XCTest
@testable import PerchCore

final class TomlMCPEditorTests: XCTestCase {
    private let spec = MCPServerSpec(command: "/Applications/Perch.app/Contents/Helpers/perch-helper", args: ["mcp"], env: ["PERCH_SOURCE": "codex"])

    private let existing = """
        model = "gpt-5.5"
        notify = ["/some/tool", "turn-ended"]

        [mcp_servers.other]
        command = "/usr/bin/other"
        args = ["serve"]

        [projects."/Users/me/app"]
        trust_level = "trusted"
        """

    func testRegisterPreservesOtherTablesAndAddsBlock() {
        let result = TomlMCPEditor.register(into: existing, name: "perch", spec: spec)

        XCTAssertTrue(result.contains("model = \"gpt-5.5\""))
        XCTAssertTrue(result.contains("[mcp_servers.other]"))
        XCTAssertTrue(result.contains("[projects.\"/Users/me/app\"]"))
        XCTAssertTrue(result.contains("[mcp_servers.perch]"))
        XCTAssertTrue(result.contains("command = \"/Applications/Perch.app/Contents/Helpers/perch-helper\""))
        XCTAssertTrue(result.contains("args = [\"mcp\"]"))
        XCTAssertTrue(result.contains("PERCH_SOURCE"))
        XCTAssertTrue(TomlMCPEditor.isRegistered(in: result, name: "perch"))
    }

    func testRegisterIsIdempotent() {
        let once = TomlMCPEditor.register(into: existing, name: "perch", spec: spec)
        let twice = TomlMCPEditor.register(into: once, name: "perch", spec: spec)
        XCTAssertEqual(once, twice)

        let occurrences = twice.components(separatedBy: "[mcp_servers.perch]").count - 1
        XCTAssertEqual(occurrences, 1)
    }

    func testUnregisterRemovesOnlyOurBlock() {
        let installed = TomlMCPEditor.register(into: existing, name: "perch", spec: spec)
        let removed = TomlMCPEditor.unregister(from: installed, name: "perch")

        XCTAssertFalse(removed.contains("[mcp_servers.perch]"))
        XCTAssertTrue(removed.contains("[mcp_servers.other]"))
        XCTAssertTrue(removed.contains("[projects.\"/Users/me/app\"]"))
        XCTAssertTrue(removed.contains("model = \"gpt-5.5\""))
    }

    func testRoundTripReturnsToOriginalContent() {
        let installed = TomlMCPEditor.register(into: existing, name: "perch", spec: spec)
        let removed = TomlMCPEditor.unregister(from: installed, name: "perch")

        // Same set of non-empty lines as the original.
        func lines(_ s: String) -> [String] {
            s.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        }
        XCTAssertEqual(lines(removed), lines(existing))
    }

    func testRegisterIntoEmptyFile() {
        let result = TomlMCPEditor.register(into: "", name: "perch", spec: spec)
        XCTAssertTrue(result.contains("[mcp_servers.perch]"))
        XCTAssertTrue(TomlMCPEditor.isRegistered(in: result, name: "perch"))
    }
}
