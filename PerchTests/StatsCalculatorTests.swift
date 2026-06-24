import XCTest
@testable import PerchCore

final class StatsCalculatorTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)) ?? Date()
    }

    func testSavedMinutesSumsAcknowledgedNotableEvents() {
        let base = date(2026, 6, 25, 9, 0)
        let events = [
            EventStat(timestamp: base, acknowledgedAt: base.addingTimeInterval(10 * 60), isNotable: true),
            EventStat(timestamp: base, acknowledgedAt: base.addingTimeInterval(5 * 60), isNotable: true),
            EventStat(timestamp: base, acknowledgedAt: nil, isNotable: true),            // not seen yet
            EventStat(timestamp: base, acknowledgedAt: base.addingTimeInterval(60), isNotable: false) // not notable
        ]
        let summary = StatsCalculator.summarize(events, now: date(2026, 6, 25, 18, 0), calendar: calendar)
        XCTAssertEqual(summary.savedMinutes, 15)
        XCTAssertEqual(summary.totalNotable, 3)
    }

    func testPerEventCapApplied() {
        let base = date(2026, 6, 25, 9, 0)
        let events = [
            EventStat(timestamp: base, acknowledgedAt: base.addingTimeInterval(10 * 60 * 60), isNotable: true)
        ]
        let summary = StatsCalculator.summarize(events, now: date(2026, 6, 25, 20, 0), calendar: calendar)
        XCTAssertEqual(summary.savedMinutes, 120) // capped at 2 hours
    }

    func testStreakCountsConsecutiveDaysEndingToday() {
        let now = date(2026, 6, 25, 20, 0)
        let events = [
            EventStat(timestamp: date(2026, 6, 25, 10), acknowledgedAt: nil, isNotable: true),
            EventStat(timestamp: date(2026, 6, 24, 10), acknowledgedAt: nil, isNotable: true),
            EventStat(timestamp: date(2026, 6, 23, 10), acknowledgedAt: nil, isNotable: true),
            EventStat(timestamp: date(2026, 6, 21, 10), acknowledgedAt: nil, isNotable: true) // gap on the 22nd
        ]
        let summary = StatsCalculator.summarize(events, now: now, calendar: calendar)
        XCTAssertEqual(summary.streakDays, 3)
    }

    func testStreakIsZeroWithoutTodayActivity() {
        let now = date(2026, 6, 25, 20, 0)
        let events = [EventStat(timestamp: date(2026, 6, 24, 10), acknowledgedAt: nil, isNotable: true)]
        let summary = StatsCalculator.summarize(events, now: now, calendar: calendar)
        XCTAssertEqual(summary.streakDays, 0)
    }

    func testPerDayWindowLength() {
        let summary = StatsCalculator.summarize([], now: date(2026, 6, 25), calendar: calendar, days: 14)
        XCTAssertEqual(summary.perDay.count, 14)
        XCTAssertEqual(summary.perDay.last?.count, 0)
    }
}
