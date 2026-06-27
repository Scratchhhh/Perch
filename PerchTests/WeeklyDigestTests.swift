import XCTest
@testable import PerchCore

final class WeeklyDigestTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func event(_ daysAgo: Double, finished: Bool = false, attention: Bool = false, project: String) -> DigestEvent {
        DigestEvent(
            timestamp: now.addingTimeInterval(-daysAgo * 86_400),
            isFinished: finished,
            demandsAttention: attention,
            projectName: project
        )
    }

    func testCountsTurnsAndWaitsWithinWindow() {
        let events = [
            event(1, finished: true, project: "Alpha"),
            event(2, finished: true, project: "Alpha"),
            event(3, attention: true, project: "Beta"),
            event(10, finished: true, project: "Alpha") // outside the 7-day window
        ]
        let digest = WeeklyDigestCalculator.summarize(events, now: now, calendar: calendar)
        XCTAssertEqual(digest.turns, 2)
        XCTAssertEqual(digest.timesWaited, 1)
        XCTAssertEqual(digest.totalEvents, 3)
    }

    func testTopProjectsRankedByNotableActivity() {
        let events = [
            event(1, finished: true, project: "Alpha"),
            event(1, attention: true, project: "Alpha"),
            event(2, finished: true, project: "Alpha"),
            event(1, finished: true, project: "Beta"),
            event(2, attention: true, project: "Gamma")
        ]
        let digest = WeeklyDigestCalculator.summarize(events, now: now, calendar: calendar, topCount: 2)
        XCTAssertEqual(digest.topProjects.count, 2)
        XCTAssertEqual(digest.topProjects.first, ProjectTally(name: "Alpha", count: 3))
        XCTAssertEqual(digest.topProjects.last?.name, "Beta") // tie broken alphabetically over Gamma
    }

    func testEmptyWeek() {
        let digest = WeeklyDigestCalculator.summarize([], now: now, calendar: calendar)
        XCTAssertEqual(digest.turns, 0)
        XCTAssertEqual(digest.timesWaited, 0)
        XCTAssertTrue(digest.topProjects.isEmpty)
    }
}
