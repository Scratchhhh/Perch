import XCTest
@testable import PerchCore

final class IncrementalLineBufferTests: XCTestCase {
    func testSplitsCompleteLines() {
        var buffer = IncrementalLineBuffer()
        let lines = buffer.append(Data("a\nb\nc\n".utf8))
        XCTAssertEqual(lines.map { String(decoding: $0, as: UTF8.self) }, ["a", "b", "c"])
    }

    func testHoldsPartialLineUntilCompleted() {
        var buffer = IncrementalLineBuffer()
        XCTAssertEqual(buffer.append(Data("hel".utf8)).count, 0)
        XCTAssertEqual(buffer.append(Data("lo".utf8)).count, 0)

        let lines = buffer.append(Data(" world\nnext".utf8))
        XCTAssertEqual(lines.map { String(decoding: $0, as: UTF8.self) }, ["hello world"])

        let finished = buffer.append(Data("\n".utf8))
        XCTAssertEqual(finished.map { String(decoding: $0, as: UTF8.self) }, ["next"])
    }

    func testResetDropsPartial() {
        var buffer = IncrementalLineBuffer()
        _ = buffer.append(Data("partial".utf8))
        buffer.reset()
        let lines = buffer.append(Data("clean\n".utf8))
        XCTAssertEqual(lines.map { String(decoding: $0, as: UTF8.self) }, ["clean"])
    }
}

final class TranscriptParserTests: XCTestCase {
    private func line(_ json: String) -> Data { Data(json.utf8) }

    func testEndTurnProducesFinishedSignal() {
        let data = line(#"{"type":"assistant","isSidechain":false,"sessionId":"abc","cwd":"/Users/me/app","timestamp":"2026-06-24T22:55:05.250Z","message":{"role":"assistant","stop_reason":"end_turn","content":[{"type":"text"}]}}"#)
        let signal = TranscriptParser.signal(forLine: data)
        XCTAssertEqual(signal?.sessionId, "abc")
        XCTAssertEqual(signal?.cwd, "/Users/me/app")
        XCTAssertEqual(signal?.kind, .finished)
        XCTAssertNotNil(signal?.timestamp)
    }

    func testToolUseIsIgnored() {
        let data = line(#"{"type":"assistant","sessionId":"abc","message":{"stop_reason":"tool_use","content":[{"type":"tool_use"}]}}"#)
        XCTAssertNil(TranscriptParser.signal(forLine: data))
    }

    func testSidechainIsIgnored() {
        let data = line(#"{"type":"assistant","isSidechain":true,"sessionId":"abc","message":{"stop_reason":"end_turn"}}"#)
        XCTAssertNil(TranscriptParser.signal(forLine: data))
    }

    func testUserMessageIsIgnored() {
        let data = line(#"{"type":"user","sessionId":"abc","message":{"role":"user","content":"hi"}}"#)
        XCTAssertNil(TranscriptParser.signal(forLine: data))
    }

    func testMissingSessionIsIgnored() {
        let data = line(#"{"type":"assistant","message":{"stop_reason":"end_turn"}}"#)
        XCTAssertNil(TranscriptParser.signal(forLine: data))
    }

    func testGarbageIsIgnored() {
        XCTAssertNil(TranscriptParser.signal(forLine: line("not json")))
        XCTAssertNil(TranscriptParser.signal(forLine: Data()))
    }
}
