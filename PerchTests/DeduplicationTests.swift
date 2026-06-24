import XCTest
@testable import PerchCore

final class DeduplicationTests: XCTestCase {
    func testDuplicateWithinWindowIsDropped() {
        let dedup = Deduplicator(window: 5)
        let start = Date(timeIntervalSince1970: 1_000)

        XCTAssertTrue(dedup.shouldProcess(sessionId: "s1", kind: .finished, at: start))
        XCTAssertFalse(dedup.shouldProcess(sessionId: "s1", kind: .finished, at: start.addingTimeInterval(2)))
        XCTAssertFalse(dedup.shouldProcess(sessionId: "s1", kind: .finished, at: start.addingTimeInterval(4.9)))
    }

    func testEventOutsideWindowIsProcessedAgain() {
        let dedup = Deduplicator(window: 5)
        let start = Date(timeIntervalSince1970: 1_000)

        XCTAssertTrue(dedup.shouldProcess(sessionId: "s1", kind: .finished, at: start))
        XCTAssertTrue(dedup.shouldProcess(sessionId: "s1", kind: .finished, at: start.addingTimeInterval(5)))
        XCTAssertTrue(dedup.shouldProcess(sessionId: "s1", kind: .finished, at: start.addingTimeInterval(11)))
    }

    func testDifferentKindIsNotDeduplicated() {
        let dedup = Deduplicator(window: 5)
        let now = Date(timeIntervalSince1970: 2_000)

        XCTAssertTrue(dedup.shouldProcess(sessionId: "s1", kind: .finished, at: now))
        XCTAssertTrue(dedup.shouldProcess(sessionId: "s1", kind: .permission, at: now))
    }

    func testDifferentSessionIsNotDeduplicated() {
        let dedup = Deduplicator(window: 5)
        let now = Date(timeIntervalSince1970: 3_000)

        XCTAssertTrue(dedup.shouldProcess(sessionId: "s1", kind: .finished, at: now))
        XCTAssertTrue(dedup.shouldProcess(sessionId: "s2", kind: .finished, at: now))
    }

    func testResetClearsHistory() {
        let dedup = Deduplicator(window: 5)
        let now = Date(timeIntervalSince1970: 4_000)

        XCTAssertTrue(dedup.shouldProcess(sessionId: "s1", kind: .finished, at: now))
        dedup.reset()
        XCTAssertTrue(dedup.shouldProcess(sessionId: "s1", kind: .finished, at: now.addingTimeInterval(1)))
    }
}
