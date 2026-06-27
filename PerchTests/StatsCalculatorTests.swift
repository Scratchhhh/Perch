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

    /// Convenience: an attention event (the only kind that counts toward focus saved).
    private func attention(at start: Date, ack: Date?) -> EventStat {
        EventStat(timestamp: start, acknowledgedAt: ack, isNotable: true, demandsAttention: true)
    }

    /// Convenience: a finish (notable for streak/histogram, but never counts as focus saved).
    private func finish(at start: Date, ack: Date?) -> EventStat {
        EventStat(timestamp: start, acknowledgedAt: ack, isNotable: true, demandsAttention: false)
    }

    // MARK: - Focus saved (union of attention intervals)

    func testFocusSavedSumsNonOverlappingAttentionIntervals() {
        let base = date(2026, 6, 25, 9, 0)
        let events = [
            attention(at: base, ack: base.addingTimeInterval(10 * 60)),                       // 10 min
            attention(at: base.addingTimeInterval(60 * 60), ack: base.addingTimeInterval(65 * 60)) // 5 min, hours later
        ]
        let summary = StatsCalculator.summarize(events, now: date(2026, 6, 25, 18, 0), calendar: calendar)
        XCTAssertEqual(summary.focusSavedMinutes, 15)
    }

    func testFocusSavedExcludesFinishedEvents() {
        let base = date(2026, 6, 25, 9, 0)
        let events = [
            finish(at: base, ack: base.addingTimeInterval(20 * 60)),     // not attention → ignored
            attention(at: base, ack: base.addingTimeInterval(10 * 60))   // 10 min
        ]
        let summary = StatsCalculator.summarize(events, now: date(2026, 6, 25, 18, 0), calendar: calendar)
        XCTAssertEqual(summary.focusSavedMinutes, 10)
        XCTAssertEqual(summary.totalNotable, 2) // both still count as notable for history/streak
    }

    func testFocusSavedUnionOfOverlappingIntervals() {
        // Two parallel agents both wait through the same ~20 min window: [0,20] and [10,30].
        // Union is [0,30] = 30 min, NOT 20 + 20 = 40.
        let base = date(2026, 6, 25, 9, 0)
        let events = [
            attention(at: base, ack: base.addingTimeInterval(20 * 60)),
            attention(at: base.addingTimeInterval(10 * 60), ack: base.addingTimeInterval(30 * 60))
        ]
        let summary = StatsCalculator.summarize(events, now: date(2026, 6, 25, 18, 0), calendar: calendar)
        XCTAssertEqual(summary.focusSavedMinutes, 30)
    }

    func testFocusSavedNestedIntervalCountsOnce() {
        // One interval fully contains another: [0,25] ⊃ [5,15]. Union is just [0,25] = 25 min.
        let base = date(2026, 6, 25, 9, 0)
        let events = [
            attention(at: base, ack: base.addingTimeInterval(25 * 60)),
            attention(at: base.addingTimeInterval(5 * 60), ack: base.addingTimeInterval(15 * 60))
        ]
        let summary = StatsCalculator.summarize(events, now: date(2026, 6, 25, 18, 0), calendar: calendar)
        XCTAssertEqual(summary.focusSavedMinutes, 25)
    }

    func testFocusSavedTouchingIntervalsAreContiguous() {
        // Back-to-back, sharing a boundary: [0,10] and [10,20] → 20 min total, no gap, no overlap.
        let base = date(2026, 6, 25, 9, 0)
        let events = [
            attention(at: base, ack: base.addingTimeInterval(10 * 60)),
            attention(at: base.addingTimeInterval(10 * 60), ack: base.addingTimeInterval(20 * 60))
        ]
        let summary = StatsCalculator.summarize(events, now: date(2026, 6, 25, 18, 0), calendar: calendar)
        XCTAssertEqual(summary.focusSavedMinutes, 20)
    }

    func testFocusSavedCapPerInterval() {
        // A single attention left unanswered for 10h is capped at 30 min.
        let base = date(2026, 6, 25, 9, 0)
        let events = [attention(at: base, ack: base.addingTimeInterval(10 * 60 * 60))]
        let summary = StatsCalculator.summarize(events, now: date(2026, 6, 25, 20, 0), calendar: calendar)
        XCTAssertEqual(summary.focusSavedMinutes, 30)
    }

    func testFocusSavedIgnoresUnacknowledged() {
        let base = date(2026, 6, 25, 9, 0)
        let events = [attention(at: base, ack: nil)]
        let summary = StatsCalculator.summarize(events, now: date(2026, 6, 25, 18, 0), calendar: calendar)
        XCTAssertEqual(summary.focusSavedMinutes, 0)
    }

    func testContextSwitchesAvoidedCountsAcknowledgedAttention() {
        let base = date(2026, 6, 25, 9, 0)
        let events = [
            attention(at: base, ack: base.addingTimeInterval(5 * 60)),   // acknowledged → counts
            attention(at: base.addingTimeInterval(60), ack: nil),        // unseen → no
            finish(at: base, ack: base.addingTimeInterval(60))           // not attention → no
        ]
        let summary = StatsCalculator.summarize(events, now: date(2026, 6, 25, 18, 0), calendar: calendar)
        XCTAssertEqual(summary.contextSwitchesAvoided, 1)
    }

    // MARK: - Streak / histogram (notable, including finishes)

    func testStreakCountsConsecutiveDaysEndingToday() {
        let now = date(2026, 6, 25, 20, 0)
        let events = [
            finish(at: date(2026, 6, 25, 10), ack: nil),
            finish(at: date(2026, 6, 24, 10), ack: nil),
            finish(at: date(2026, 6, 23, 10), ack: nil),
            finish(at: date(2026, 6, 21, 10), ack: nil) // gap on the 22nd
        ]
        let summary = StatsCalculator.summarize(events, now: now, calendar: calendar)
        XCTAssertEqual(summary.streakDays, 3)
    }

    func testStreakIsZeroWithoutTodayActivity() {
        let now = date(2026, 6, 25, 20, 0)
        let events = [finish(at: date(2026, 6, 24, 10), ack: nil)]
        let summary = StatsCalculator.summarize(events, now: now, calendar: calendar)
        XCTAssertEqual(summary.streakDays, 0)
    }

    func testPerDayWindowLength() {
        let summary = StatsCalculator.summarize([], now: date(2026, 6, 25), calendar: calendar, days: 14)
        XCTAssertEqual(summary.perDay.count, 14)
        XCTAssertEqual(summary.perDay.last?.count, 0)
    }

    func testTotalNotableCountsFinishesAndAttention() {
        let base = date(2026, 6, 25, 9, 0)
        let events = [
            finish(at: base, ack: nil),
            attention(at: base, ack: nil),
            EventStat(timestamp: base, acknowledgedAt: nil, isNotable: false, demandsAttention: false)
        ]
        let summary = StatsCalculator.summarize(events, now: date(2026, 6, 25, 18, 0), calendar: calendar)
        XCTAssertEqual(summary.totalNotable, 2)
    }
}
