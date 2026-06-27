import XCTest
@testable import PerchCore

final class NotificationCoalescerTests: XCTestCase {
    private func notice(_ kind: EventKind, _ project: String, session: String = UUID().uuidString) -> PendingNotice {
        PendingNotice(sessionId: session, kind: kind, projectName: project)
    }

    func testEmptyReturnsNil() {
        XCTAssertNil(NotificationCoalescer.summarize([]))
    }

    func testSingleFinish() {
        let summary = NotificationCoalescer.summarize([notice(.finished, "Alpha")])
        XCTAssertEqual(summary?.count, 1)
        XCTAssertEqual(summary?.title, "1 agent finished")
        XCTAssertEqual(summary?.primaryKind, .finished)
    }

    func testThreeFinishesGroup() {
        let summary = NotificationCoalescer.summarize([
            notice(.finished, "Alpha"),
            notice(.finished, "Beta"),
            notice(.finished, "Gamma")
        ])
        XCTAssertEqual(summary?.title, "3 agents finished")
        XCTAssertEqual(summary?.body, "Alpha, Beta, Gamma")
        XCTAssertEqual(summary?.primaryKind, .finished)
        XCTAssertEqual(summary?.count, 3)
    }

    func testAttentionOnlyGroup() {
        let summary = NotificationCoalescer.summarize([
            notice(.permission, "Alpha"),
            notice(.needsInput, "Beta")
        ])
        XCTAssertEqual(summary?.title, "2 agents need you")
        XCTAssertTrue(summary?.primaryKind.demandsAttention ?? false)
    }

    func testMixedBucketsUseBreakdown() {
        let summary = NotificationCoalescer.summarize([
            notice(.permission, "Alpha"),
            notice(.needsInput, "Beta"),
            notice(.finished, "Gamma")
        ])
        XCTAssertEqual(summary?.title, "3 agent updates")
        XCTAssertEqual(summary?.body, "2 need you · 1 finished")
        // Attention present → primary kind must demand attention so the banner uses that category.
        XCTAssertTrue(summary?.primaryKind.demandsAttention ?? false)
    }

    func testProjectListDeduplicatesAndAbbreviates() {
        let summary = NotificationCoalescer.summarize([
            notice(.finished, "Alpha"),
            notice(.finished, "Alpha"),    // dup project
            notice(.finished, "Beta"),
            notice(.finished, "Gamma"),
            notice(.finished, "Delta")
        ])
        // Four unique projects (Alpha, Beta, Gamma, Delta) → first three then "+1 more".
        XCTAssertEqual(summary?.body, "Alpha, Beta, Gamma +1 more")
        XCTAssertEqual(summary?.count, 5)
    }
}
