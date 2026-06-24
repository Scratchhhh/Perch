import XCTest
@testable import PerchCore

final class RelayMessageTests: XCTestCase {
    func testEnvelopeRoundTrips() throws {
        let message = RelayMessage(
            sessionId: "abc123",
            source: .claudeCode,
            channel: .hook,
            kind: .finished,
            message: "All tests pass.",
            project: "/Users/me/code/app",
            transcriptPath: "/Users/me/.claude/projects/app/transcript.jsonl",
            timestamp: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let envelope = RelayEnvelope(token: "secret-token", message: message)

        let data = try PerchJSON.encoder().encode(envelope)
        let decoded = try PerchJSON.decoder().decode(RelayEnvelope.self, from: data)

        XCTAssertEqual(decoded.token, "secret-token")
        XCTAssertEqual(decoded.message, message)
    }

    func testKindMapsToExpectedState() {
        XCTAssertEqual(EventKind.finished.resultingState, .done)
        XCTAssertEqual(EventKind.started.resultingState, .working)
        XCTAssertEqual(EventKind.subagentDone.resultingState, .working)
        XCTAssertEqual(EventKind.needsInput.resultingState, .waiting)
        XCTAssertEqual(EventKind.permission.resultingState, .waiting)
        XCTAssertEqual(EventKind.blocked.resultingState, .waiting)
    }

    func testAttentionFlag() {
        XCTAssertTrue(EventKind.permission.demandsAttention)
        XCTAssertTrue(EventKind.needsInput.demandsAttention)
        XCTAssertTrue(EventKind.blocked.demandsAttention)
        XCTAssertFalse(EventKind.finished.demandsAttention)
        XCTAssertFalse(EventKind.started.demandsAttention)
    }

    func testDecodingRejectsUnknownEnum() {
        let json = Data(#"{"token":"t","message":{"sessionId":"s","source":"martian","channel":"hook","kind":"finished","message":"","timestamp":"2023-11-14T22:13:20Z"}}"#.utf8)
        XCTAssertThrowsError(try PerchJSON.decoder().decode(RelayEnvelope.self, from: json))
    }
}
