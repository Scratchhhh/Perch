import XCTest
@testable import PerchCore

final class MascotMoodTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    func testAttentionWinsOverWorking() {
        let mood = MascotMoodPolicy.mood(
            hasAttention: true, attentionKind: .needsInput, workingCount: 3,
            lastKind: .started, lastEventAt: now, now: now
        )
        XCTAssertEqual(mood, .asking)
    }

    func testPermissionMapsToPermission() {
        let mood = MascotMoodPolicy.mood(
            hasAttention: true, attentionKind: .permission, workingCount: 0,
            lastKind: .permission, lastEventAt: now, now: now
        )
        XCTAssertEqual(mood, .permission)
    }

    func testBlockedMapsToAlert() {
        let mood = MascotMoodPolicy.mood(
            hasAttention: true, attentionKind: .blocked, workingCount: 0,
            lastKind: .blocked, lastEventAt: now, now: now
        )
        XCTAssertEqual(mood, .alert)
    }

    func testWorkingShowsWorkingNotSleeping() {
        let mood = MascotMoodPolicy.mood(
            hasAttention: false, attentionKind: nil, workingCount: 2,
            lastKind: .started, lastEventAt: now, now: now
        )
        XCTAssertEqual(mood, .working)
    }

    func testRecentFinishIsHappy() {
        let mood = MascotMoodPolicy.mood(
            hasAttention: false, attentionKind: nil, workingCount: 0,
            lastKind: .finished, lastEventAt: now.addingTimeInterval(-2), now: now
        )
        XCTAssertEqual(mood, .happy)
    }

    func testStaleFinishFallsBackToIdle() {
        let mood = MascotMoodPolicy.mood(
            hasAttention: false, attentionKind: nil, workingCount: 0,
            lastKind: .finished, lastEventAt: now.addingTimeInterval(-60), now: now
        )
        XCTAssertEqual(mood, .idle)
    }

    func testNothingHappeningIsIdle() {
        let mood = MascotMoodPolicy.mood(
            hasAttention: false, attentionKind: nil, workingCount: 0,
            lastKind: nil, lastEventAt: nil, now: now
        )
        XCTAssertEqual(mood, .idle)
    }

    func testAttentionWithoutKindFallsBackToAsking() {
        let mood = MascotMoodPolicy.mood(
            hasAttention: true, attentionKind: nil, workingCount: 0,
            lastKind: nil, lastEventAt: nil, now: now
        )
        XCTAssertEqual(mood, .asking)
    }
}
