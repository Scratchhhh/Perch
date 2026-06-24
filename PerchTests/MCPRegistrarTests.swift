import XCTest
@testable import PerchCore

final class MCPRegistrarTests: XCTestCase {
    private let spec = MCPServerSpec(command: "/Applications/Perch.app/Contents/Helpers/perch-helper", args: ["mcp"], env: ["PERCH_SOURCE": "cursor"])

    private func object(_ data: Data) throws -> [String: Any] {
        try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func testRegisterPreservesExistingServers() throws {
        let existing = Data(#"{"mcpServers":{"unityMCP":{"type":"stdio","command":"/bin/uvx","args":["x"]}}}"#.utf8)
        let result = try MCPServerRegistrar.register(into: existing, name: "perch", spec: spec)

        let servers = try XCTUnwrap(try object(result)["mcpServers"] as? [String: Any])
        XCTAssertNotNil(servers["unityMCP"])
        let perch = try XCTUnwrap(servers["perch"] as? [String: Any])
        XCTAssertEqual(perch["command"] as? String, spec.command)
        XCTAssertEqual(perch["args"] as? [String], ["mcp"])
        XCTAssertEqual((perch["env"] as? [String: String])?["PERCH_SOURCE"], "cursor")
    }

    func testRegisterPreservesForeignTopLevelKeys() throws {
        let existing = Data(#"{"numStartups":7,"userID":"abc","mcpServers":{}}"#.utf8)
        let result = try MCPServerRegistrar.register(into: existing, name: "perch", spec: spec)
        let root = try object(result)

        XCTAssertEqual(root["numStartups"] as? Int, 7)
        XCTAssertEqual(root["userID"] as? String, "abc")
        XCTAssertTrue(MCPServerRegistrar.isRegistered(in: result, name: "perch"))
    }

    func testRegisterIsIdempotent() throws {
        let once = try MCPServerRegistrar.register(into: nil, name: "perch", spec: spec)
        let twice = try MCPServerRegistrar.register(into: once, name: "perch", spec: spec)
        XCTAssertEqual(once, twice)
    }

    func testUnregisterRemovesOnlyOurs() throws {
        let existing = Data(#"{"mcpServers":{"unityMCP":{"command":"/bin/uvx","args":[]}}}"#.utf8)
        let installed = try MCPServerRegistrar.register(into: existing, name: "perch", spec: spec)
        let removed = try MCPServerRegistrar.unregister(from: installed, name: "perch")

        let servers = try XCTUnwrap(try object(removed)["mcpServers"] as? [String: Any])
        XCTAssertNotNil(servers["unityMCP"])
        XCTAssertNil(servers["perch"])
        XCTAssertFalse(MCPServerRegistrar.isRegistered(in: removed, name: "perch"))
    }
}
