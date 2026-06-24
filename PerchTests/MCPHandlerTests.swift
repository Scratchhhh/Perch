import XCTest
@testable import PerchCore

final class MCPHandlerTests: XCTestCase {
    private func makeHandler() -> MCPHandler {
        MCPHandler(serverName: "perch", serverVersion: "1.0", sessionId: "fixed-session", source: .cursor)
    }

    private func send(_ json: String, to handler: MCPHandler) -> MCPResult {
        handler.handle(line: Data(json.utf8))
    }

    private func object(_ data: Data) throws -> [String: Any] {
        try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func testInitializeEchoesProtocolAndAdvertisesServer() throws {
        let handler = makeHandler()
        let result = send(#"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","clientInfo":{"name":"cursor"}}}"#, to: handler)

        let response = try object(try XCTUnwrap(result.responseLines.first))
        XCTAssertEqual(response["jsonrpc"] as? String, "2.0")
        let payload = try XCTUnwrap(response["result"] as? [String: Any])
        XCTAssertEqual(payload["protocolVersion"] as? String, "2025-06-18")
        let serverInfo = try XCTUnwrap(payload["serverInfo"] as? [String: Any])
        XCTAssertEqual(serverInfo["name"] as? String, "perch")
        XCTAssertNotNil(payload["capabilities"])
    }

    func testToolsListExposesPerchNotify() throws {
        let handler = makeHandler()
        let result = send(#"{"jsonrpc":"2.0","id":2,"method":"tools/list"}"#, to: handler)

        let response = try object(try XCTUnwrap(result.responseLines.first))
        let payload = try XCTUnwrap(response["result"] as? [String: Any])
        let tools = try XCTUnwrap(payload["tools"] as? [[String: Any]])
        XCTAssertEqual(tools.first?["name"] as? String, "perch_notify")

        let schema = try XCTUnwrap(tools.first?["inputSchema"] as? [String: Any])
        let required = try XCTUnwrap(schema["required"] as? [String])
        XCTAssertEqual(Set(required), ["status", "message"])
    }

    func testToolsCallRelaysAndAcknowledges() throws {
        let handler = makeHandler()
        let result = send(#"{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"perch_notify","arguments":{"status":"question","message":"Need the API key","project":"/Users/me/api"}}}"#, to: handler)

        let relay = try XCTUnwrap(result.relay)
        XCTAssertEqual(relay.sessionId, "fixed-session")
        XCTAssertEqual(relay.source, .cursor)
        XCTAssertEqual(relay.channel, .mcp)
        XCTAssertEqual(relay.kind, .needsInput)
        XCTAssertEqual(relay.message, "Need the API key")
        XCTAssertEqual(relay.project, "/Users/me/api")

        let response = try object(try XCTUnwrap(result.responseLines.first))
        let payload = try XCTUnwrap(response["result"] as? [String: Any])
        XCTAssertEqual(payload["isError"] as? Bool, false)
    }

    func testStatusMapping() {
        XCTAssertEqual(MCPHandler.kind(forStatus: "done"), .finished)
        XCTAssertEqual(MCPHandler.kind(forStatus: "question"), .needsInput)
        XCTAssertEqual(MCPHandler.kind(forStatus: "blocked"), .blocked)
        XCTAssertEqual(MCPHandler.kind(forStatus: "weird"), .finished)
    }

    func testUnknownToolReturnsToolError() throws {
        let handler = makeHandler()
        let result = send(#"{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"nope","arguments":{}}}"#, to: handler)

        XCTAssertNil(result.relay)
        let response = try object(try XCTUnwrap(result.responseLines.first))
        let payload = try XCTUnwrap(response["result"] as? [String: Any])
        XCTAssertEqual(payload["isError"] as? Bool, true)
    }

    func testPingReturnsEmptyResult() throws {
        let handler = makeHandler()
        let result = send(#"{"jsonrpc":"2.0","id":5,"method":"ping"}"#, to: handler)
        let response = try object(try XCTUnwrap(result.responseLines.first))
        XCTAssertNotNil(response["result"])
    }

    func testNotificationProducesNoResponse() {
        let handler = makeHandler()
        let result = send(#"{"jsonrpc":"2.0","method":"notifications/initialized"}"#, to: handler)
        XCTAssertTrue(result.responseLines.isEmpty)
        XCTAssertNil(result.relay)
    }

    func testUnknownMethodWithIdReturnsError() throws {
        let handler = makeHandler()
        let result = send(#"{"jsonrpc":"2.0","id":6,"method":"resources/list"}"#, to: handler)
        let response = try object(try XCTUnwrap(result.responseLines.first))
        let error = try XCTUnwrap(response["error"] as? [String: Any])
        XCTAssertEqual(error["code"] as? Int, -32601)
    }

    func testGarbageLineReturnsParseError() throws {
        let handler = makeHandler()
        let result = send("not json at all", to: handler)
        let response = try object(try XCTUnwrap(result.responseLines.first))
        let error = try XCTUnwrap(response["error"] as? [String: Any])
        XCTAssertEqual(error["code"] as? Int, -32700)
    }
}
